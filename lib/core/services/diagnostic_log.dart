import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:hive/hive.dart';

import '../constants.dart';

/// 单条消息上限（约 2KB）。
const diagnosticMessageBytes = 2048;

/// 单条堆栈上限（约 8KB）。
const diagnosticStackBytes = 8192;

/// 环形日志最多保留的条数。
const diagnosticMaxEvents = 200;

/// 用户说明最长字符数。
const diagnosticNoteRunes = 500;

/// 单次上报体目标上限，留给传输层余量，服务端硬限制是 64KB。
const diagnosticMaxBodyBytes = 60 * 1024;

const diagnosticContextKeys = {
  'appVersion',
  'os',
  'osVersion',
  'route',
  'installId',
  'accountId',
};

const diagnosticEventKeys = {'at', 'level', 'kind', 'message', 'stack'};

/// 去掉 token、密码和答题字段，只保留上报允许的键。
Map<String, dynamic> sanitizeDiagnosticReport(Map<String, dynamic> raw) {
  final events = raw['events'];
  final context = raw['context'];
  return {
    'reportId': raw['reportId'],
    'note': raw['note'],
    'context': _whitelistMap(context, diagnosticContextKeys),
    'events': [
      if (events is List)
        for (final event in events)
          if (event is Map) _whitelistMap(event, diagnosticEventKeys),
    ],
  };
}

Map<String, dynamic> _whitelistMap(Object? raw, Set<String> keys) {
  if (raw is! Map) return {};
  final map = <String, dynamic>{};
  for (final key in keys) {
    final value = raw[key];
    if (value is String) map[key] = value;
  }
  return map;
}

String redactDiagnosticText(String value) {
  var text = value;
  text = text.replaceAll(
    RegExp(r'Bearer\s+\S+', caseSensitive: false),
    'Bearer [redacted]',
  );
  text = text.replaceAll(
    RegExp(
      r'(accessToken|refreshToken|passwordHash|password|token)\s*[:=]\s*\S+',
      caseSensitive: false,
    ),
    '[redacted]',
  );
  return text;
}

String truncateUtf8(String value, int maxBytes) {
  if (utf8.encode(value).length <= maxBytes) return value;
  final buffer = StringBuffer();
  var size = 0;
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final next = utf8.encode(char).length;
    if (size + next > maxBytes) break;
    buffer.write(char);
    size += next;
  }
  return buffer.toString();
}

String? truncateNote(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final runes = trimmed.runes.toList();
  if (runes.length <= diagnosticNoteRunes) return trimmed;
  return String.fromCharCodes(runes.take(diagnosticNoteRunes));
}

String newDiagnosticId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// 全局入口。未安装时调用方静默跳过，避免音效等路径在测试里被迫初始化 Hive。
void recordDiagnosticError(String kind, Object error, [StackTrace? stack]) {
  final log = DiagnosticLog.instance;
  if (log == null) return;
  unawaited(
    log.record(level: 'error', kind: kind, message: '$error', stack: stack),
  );
}

void recordDiagnosticCrash(String kind, Object error, [StackTrace? stack]) {
  final log = DiagnosticLog.instance;
  if (log == null) return;
  unawaited(
    log.record(level: 'crash', kind: kind, message: '$error', stack: stack),
  );
}

/// 与学习记录分开的本地诊断环形日志，以及尚未上传的报告队列。
class DiagnosticLog {
  DiagnosticLog({
    Box<String>? box,
    DateTime Function()? clock,
    this.os,
    this.osVersion,
  }) : _box = box,
       clock = clock ?? DateTime.now {
    final saved = this.box.get(_routeKey);
    if (saved != null) route = saved;
  }

  static const boxName = 'diagnostics';
  static const _eventsKey = 'events';
  static const _pendingKey = 'pending';
  static const _routeKey = 'route';

  static DiagnosticLog? instance;

  static void install(DiagnosticLog log) {
    instance = log;
  }

  final Box<String>? _box;
  final DateTime Function() clock;
  final String? os;
  final String? osVersion;

  String route = '';
  String? _lastCrashKey;
  DateTime? _lastCrashAt;

  Box<String> get box => _box ?? Hive.box<String>(boxName);

  Future<void> setRoute(String value) async {
    route = value;
    try {
      await box.put(_routeKey, value);
    } catch (_) {}
  }

  Future<void> record({
    required String level,
    required String kind,
    required String message,
    StackTrace? stack,
  }) async {
    try {
      final safeMessage = truncateUtf8(
        redactDiagnosticText(message),
        diagnosticMessageBytes,
      );
      final safeStack = stack == null
          ? null
          : truncateUtf8(redactDiagnosticText('$stack'), diagnosticStackBytes);
      if (level == 'crash' && _duplicateCrash(safeMessage)) return;

      final list = _readList(_eventsKey);
      list.add({
        'id': newDiagnosticId(),
        'at': clock().toUtc().toIso8601String(),
        'level': level,
        'kind': kind,
        'message': safeMessage,
        'queued': false,
        if (safeStack != null && safeStack.isNotEmpty) 'stack': safeStack,
      });
      if (list.length > diagnosticMaxEvents) {
        list.removeRange(0, list.length - diagnosticMaxEvents);
      }
      await box.put(_eventsKey, jsonEncode(list));
    } catch (_) {}
  }

  bool _duplicateCrash(String message) {
    final key = message;
    final now = clock();
    final previous = _lastCrashAt;
    if (_lastCrashKey == key &&
        previous != null &&
        now.difference(previous) < const Duration(seconds: 2)) {
      return true;
    }
    _lastCrashKey = key;
    _lastCrashAt = now;
    return false;
  }

  List<Map<String, dynamic>> get events => _readList(_eventsKey);

  List<Map<String, dynamic>> get pending => _readList(_pendingKey);

  /// 把还没装进报告的事件打成一条无说明报告。没有新事件时不产生报告。
  Future<void> enqueueUnsent({
    required String installId,
    String? accountId,
  }) async {
    final fresh = [
      for (final event in events)
        if (event['queued'] != true) event,
    ];
    if (fresh.isEmpty) return;
    await _enqueue(
      fresh,
      note: null,
      installId: installId,
      accountId: accountId,
    );
  }

  /// 用户反馈：带上当前环形日志里的最近记录。说明可空。
  Future<void> enqueueFeedback({
    required String note,
    required String installId,
    String? accountId,
  }) async {
    await _enqueue(
      events,
      note: note,
      installId: installId,
      accountId: accountId,
    );
  }

  Future<void> markSent(String reportId) async {
    final list = pending;
    list.removeWhere((report) => report['reportId'] == reportId);
    await box.put(_pendingKey, jsonEncode(list));
  }

  Future<void> _enqueue(
    List<Map<String, dynamic>> source, {
    required String? note,
    required String installId,
    required String? accountId,
  }) async {
    final included = {
      for (final event in source)
        if (event['id'] is String) event['id'] as String,
    };
    final report = _fit({
      'reportId': newDiagnosticId(),
      'note': truncateNote(note),
      'context': {
        'appVersion': kAppVersion,
        'os': os ?? Platform.operatingSystem,
        'osVersion': osVersion ?? Platform.operatingSystemVersion,
        'route': route,
        'installId': installId,
        if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
      },
      'events': [for (final event in source) _publicEvent(event)],
    });
    final queue = pending;
    queue.add(sanitizeDiagnosticReport(report));
    await box.put(_pendingKey, jsonEncode(queue));

    if (included.isEmpty) return;
    final list = events;
    for (final event in list) {
      if (included.contains(event['id'])) event['queued'] = true;
    }
    await box.put(_eventsKey, jsonEncode(list));
  }

  Map<String, dynamic> _publicEvent(Map<String, dynamic> event) => {
    'at': event['at'],
    'level': event['level'],
    'kind': event['kind'],
    'message': event['message'],
    if (event['stack'] is String) 'stack': event['stack'],
  };

  Map<String, dynamic> _fit(Map<String, dynamic> report) {
    final events = (report['events'] as List).cast<Map<String, dynamic>>();
    while (events.isNotEmpty &&
        utf8.encode(jsonEncode(report)).length > diagnosticMaxBodyBytes) {
      events.removeAt(0);
    }
    return report;
  }

  List<Map<String, dynamic>> _readList(String key) {
    final raw = box.get(key);
    if (raw == null) return [];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return [];
      return [
        for (final item in value)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    } catch (_) {
      return [];
    }
  }
}
