import 'dart:convert';
import 'dart:io';

import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/core/services/diagnostic_log.dart';
import 'package:english_village/core/services/diagnostic_uploader.dart';
import 'package:english_village/data/sources/report_api.dart';
import 'package:english_village/data/sources/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory tempDir;
  late DiagnosticLog log;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('diagnostic_log_test');
    Hive.init(tempDir.path);
    final box = await Hive.openBox<String>(DiagnosticLog.boxName);
    await Hive.openBox<String>(SettingsStore.boxName);
    log = DiagnosticLog(box: box, os: 'android', osVersion: '14');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('超过 200 条时丢掉最旧的', () async {
    var tick = DateTime.utc(2026, 1, 1);
    final capped = DiagnosticLog(
      box: Hive.box<String>(DiagnosticLog.boxName),
      clock: () => tick,
      os: 'android',
      osVersion: '14',
    );
    for (var i = 0; i < diagnosticMaxEvents + 1; i++) {
      tick = DateTime.utc(2026, 1, 1).add(Duration(seconds: i));
      await capped.record(level: 'error', kind: 'tts', message: 'm$i');
    }

    expect(capped.events, hasLength(diagnosticMaxEvents));
    expect(capped.events.first['message'], 'm1');
    expect(capped.events.last['message'], 'm$diagnosticMaxEvents');
  });

  test('消息和堆栈按字节上限截断', () async {
    await log.record(
      level: 'error',
      kind: 'tts',
      message: 'a' * (diagnosticMessageBytes + 400),
      stack: StackTrace.fromString('b' * (diagnosticStackBytes + 400)),
    );

    final event = log.events.single;
    expect(
      utf8.encode(event['message'] as String).length,
      diagnosticMessageBytes,
    );
    expect(
      utf8.encode(event['stack'] as String).length,
      lessThanOrEqualTo(diagnosticStackBytes),
    );
  });

  test('上报体不含 token 和答题字段', () async {
    final sanitized = sanitizeDiagnosticReport({
      'reportId': 'abc12345',
      'note': '听不到',
      'accessToken': 'secret-token',
      'password': 'hunter2',
      'context': {
        'appVersion': '0.8.32',
        'accountId': 'acc',
        'accessToken': 'secret-token',
        'email': 'a@b.c',
      },
      'events': [
        {
          'at': 't',
          'level': 'error',
          'kind': 'tts',
          'message': 'fail',
          'stack': 's',
          'answer': 'hello',
          'token': 'secret-token',
        },
      ],
    });
    final text = jsonEncode(sanitized);
    expect(text.contains('secret-token'), isFalse);
    expect(text.contains('hunter2'), isFalse);
    expect(text.contains('hello'), isFalse);
    expect(text.contains('a@b.c'), isFalse);
    expect(sanitized['context'].containsKey('accessToken'), isFalse);
    expect((sanitized['events'] as List).single.containsKey('answer'), isFalse);

    await log.record(
      level: 'error',
      kind: 'sync',
      message: 'accessToken=super-secret password=hunter2',
      stack: StackTrace.fromString('Bearer abc.def.ghi'),
    );
    await log.enqueueFeedback(note: '听不到', installId: 'install-1');
    final pending = jsonEncode(log.pending.single);
    expect(pending.contains('super-secret'), isFalse);
    expect(pending.contains('hunter2'), isFalse);
    expect(pending.contains('abc.def.ghi'), isFalse);
    expect(pending.contains('accessToken'), isFalse);
  });

  test('失败后用同一个 reportId 重试，正文不带 access token', () async {
    await log.record(level: 'error', kind: 'tts', message: 'play failed');
    String? reportId;
    var calls = 0;
    final api = ReportApi(
      baseUrl: 'http://localhost:8787/v1',
      client: MockClient((request) async {
        calls++;
        expect(request.headers['authorization'], 'Bearer secret-token');
        expect(request.body.contains('secret-token'), isFalse);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('accessToken'), isFalse);
        expect(body['context'].containsKey('accessToken'), isFalse);
        reportId ??= body['reportId'] as String;
        expect(body['reportId'], reportId);
        if (calls == 1) return http.Response('fail', 500);
        return http.Response('{"ok":true}', 200);
      }),
    );
    final uploader = DiagnosticUploader(
      log: log,
      api: api,
      settings: SettingsStore(),
      readAuth: () => const AuthState(
        userKey: 'online:account-1',
        accessToken: 'secret-token',
      ),
    );

    expect(await uploader.submitNote('听不到'), isFalse);
    expect(log.pending, hasLength(1));
    expect(await uploader.flush(), isTrue);
    expect(calls, 2);
    expect(log.pending, isEmpty);
  });
}
