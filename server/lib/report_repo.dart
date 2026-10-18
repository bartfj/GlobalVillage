import 'dart:convert';

import 'package:postgres/postgres.dart';

/// 单次上报正文上限。
const maxReportBodyBytes = 64 * 1024;

/// 库存最多保留的报告条数。
const maxStoredReports = 500;

const _reportIdPattern = r'^[A-Za-z0-9_-]{8,80}$';

const _contextKeys = {
  'appVersion',
  'os',
  'osVersion',
  'route',
  'lesson',
  'installId',
  'accountId',
};

const _eventKeys = {'at', 'level', 'kind', 'message', 'stack'};

/// 一条客户端诊断报告。
class ClientReport {
  ClientReport({
    required this.reportId,
    required this.receivedAt,
    required this.appVersion,
    required this.context,
    required this.events,
    this.accountId,
    this.note,
  });

  final String reportId;
  final DateTime receivedAt;
  final String? accountId;
  final String appVersion;
  final String? note;
  final Map<String, dynamic> context;
  final List<Map<String, dynamic>> events;

  Map<String, Object?> toListJson() => {
    'reportId': reportId,
    'receivedAt': receivedAt.toUtc().toIso8601String(),
    'accountId': accountId,
    'appVersion': appVersion,
    'note': note,
    'lesson': context['lesson'],
    'eventCount': events.length,
  };

  Map<String, Object?> toDetailJson() => {
    ...toListJson(),
    'context': context,
    'events': events,
  };
}

/// 请求体不是合法报告。
class InvalidReportException implements Exception {
  const InvalidReportException();
}

/// 解析并裁剪客户端上报。非法返回时抛 [InvalidReportException]。
ClientReport parseClientReport(
  Map<String, dynamic> body, {
  String? accountId,
  DateTime? receivedAt,
}) {
  final reportId = body['reportId'];
  if (reportId is! String || !RegExp(_reportIdPattern).hasMatch(reportId)) {
    throw const InvalidReportException();
  }

  final rawEvents = body['events'];
  if (rawEvents is! List) throw const InvalidReportException();

  final rawContext = body['context'];
  if (rawContext != null && rawContext is! Map) {
    throw const InvalidReportException();
  }

  final note = _note(body['note']);
  final events = [
    for (final item in rawEvents)
      if (item is Map) _event(item),
  ].whereType<Map<String, dynamic>>().toList();
  if (events.length > 200) {
    events.removeRange(0, events.length - 200);
  }
  if (note == null && events.isEmpty) throw const InvalidReportException();

  final context = _context(rawContext);
  final version = context['appVersion'] ?? 'unknown';
  // 账号只信已验证的 access token，不采用客户端自报的 accountId。
  context.remove('accountId');
  if (accountId != null) context['accountId'] = accountId;

  return ClientReport(
    reportId: reportId,
    receivedAt: (receivedAt ?? DateTime.now()).toUtc(),
    accountId: accountId,
    appVersion: version,
    note: note,
    context: context,
    events: events,
  );
}

String? _note(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const InvalidReportException();
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final runes = trimmed.runes.toList();
  if (runes.length <= 500) return trimmed;
  return String.fromCharCodes(runes.take(500));
}

Map<String, dynamic> _context(Object? raw) {
  final map = <String, dynamic>{};
  if (raw is! Map) return map;
  for (final key in _contextKeys) {
    final value = raw[key];
    if (value is String && value.length <= 512) map[key] = value;
  }
  return map;
}

Map<String, dynamic>? _event(Map raw) {
  final message = raw['message'];
  if (message is! String || message.isEmpty) return null;
  final event = <String, dynamic>{};
  for (final key in _eventKeys) {
    final value = raw[key];
    if (value is String) event[key] = value;
  }
  return event;
}

abstract class ReportRepo {
  /// 新报告返回 true。相同 [ClientReport.reportId] 已存在时返回 false，不覆盖。
  Future<bool> insert(ClientReport report);

  Future<List<ClientReport>> list({int limit = 100});

  Future<ClientReport?> get(String reportId);
}

/// 内存实现。新实例为空，与账号内存仓储一样，进程重启后丢失。
class InMemoryReportRepo implements ReportRepo {
  final _items = <ClientReport>[];

  @override
  Future<bool> insert(ClientReport report) async {
    if (_items.any((item) => item.reportId == report.reportId)) return false;
    _items.insert(0, report);
    if (_items.length > maxStoredReports) {
      _items.removeRange(maxStoredReports, _items.length);
    }
    return true;
  }

  @override
  Future<List<ClientReport>> list({int limit = 100}) async =>
      _items.take(limit).toList();

  @override
  Future<ClientReport?> get(String reportId) async {
    for (final item in _items) {
      if (item.reportId == reportId) return item;
    }
    return null;
  }
}

/// Postgres 实现（表 client_reports）。
class PostgresReportRepo implements ReportRepo {
  PostgresReportRepo._(this._conn);

  final Connection _conn;

  static Future<PostgresReportRepo> connect(String databaseUrl) async {
    final uri = Uri.parse(databaseUrl);
    final userInfo = uri.userInfo.split(':');
    final sslRequired = uri.queryParameters['sslmode'] == 'require';
    final conn = await Connection.open(
      Endpoint(
        host: uri.host.isEmpty ? 'localhost' : uri.host,
        port: uri.port == 0 ? 5432 : uri.port,
        database: uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : 'postgres',
        username: userInfo.first.isEmpty ? null : userInfo.first,
        password: userInfo.length > 1 ? userInfo.sublist(1).join(':') : null,
      ),
      settings: ConnectionSettings(
        sslMode: sslRequired ? SslMode.require : SslMode.disable,
      ),
    );
    final repo = PostgresReportRepo._(conn);
    await repo._migrate();
    return repo;
  }

  Future<void> _migrate() async {
    await _conn.execute('''
CREATE TABLE IF NOT EXISTS client_reports (
  report_id text PRIMARY KEY,
  received_at timestamptz NOT NULL DEFAULT now(),
  account_id uuid,
  app_version text NOT NULL,
  note text,
  context jsonb NOT NULL,
  events jsonb NOT NULL
)
''');
  }

  @override
  Future<bool> insert(ClientReport report) async {
    final result = await _conn.execute(
      Sql.named('''
INSERT INTO client_reports (
  report_id, account_id, app_version, note, context, events
)
VALUES (
  @id,
  CASE WHEN @accountId = '' THEN NULL::uuid ELSE @accountId::uuid END,
  @version,
  NULLIF(@note, ''),
  @context::jsonb,
  @events::jsonb
)
ON CONFLICT (report_id) DO NOTHING
RETURNING report_id
'''),
      parameters: {
        'id': report.reportId,
        'accountId': report.accountId ?? '',
        'version': report.appVersion,
        'note': report.note ?? '',
        'context': jsonEncode(report.context),
        'events': jsonEncode(report.events),
      },
    );
    if (result.isEmpty) return false;
    await _conn.execute('''
DELETE FROM client_reports
WHERE report_id IN (
  SELECT report_id FROM client_reports
  ORDER BY received_at DESC
  OFFSET $maxStoredReports
)
''');
    return true;
  }

  @override
  Future<List<ClientReport>> list({int limit = 100}) async {
    final result = await _conn.execute(
      Sql.named('''
SELECT report_id, received_at, account_id::text AS account_id, app_version,
       note, context, events
FROM client_reports
ORDER BY received_at DESC
LIMIT @limit
'''),
      parameters: {'limit': limit},
    );
    return [for (final row in result) _fromRow(row.toColumnMap())];
  }

  @override
  Future<ClientReport?> get(String reportId) async {
    final result = await _conn.execute(
      Sql.named('''
SELECT report_id, received_at, account_id::text AS account_id, app_version,
       note, context, events
FROM client_reports
WHERE report_id = @id
LIMIT 1
'''),
      parameters: {'id': reportId},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  ClientReport _fromRow(Map<String, dynamic> row) {
    final context = row['context'];
    final events = row['events'];
    return ClientReport(
      reportId: row['report_id'] as String,
      receivedAt: row['received_at'] as DateTime,
      accountId: row['account_id'] as String?,
      appVersion: row['app_version'] as String,
      note: row['note'] as String?,
      context: context is Map
          ? Map<String, dynamic>.from(context)
          : <String, dynamic>{},
      events: [
        if (events is List)
          for (final item in events)
            if (item is Map) Map<String, dynamic>.from(item),
      ],
    );
  }
}
