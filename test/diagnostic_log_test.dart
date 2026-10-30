import 'dart:convert';
import 'dart:io';

import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/core/services/diagnostic_log.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/learning_language.dart';
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

  test('反馈带上具体课程，离开该课后不再沿用', () async {
    const course = Course(
      id: 'intermediate',
      title: '英语中级',
      language: LearningLanguage.english,
      units: [
        Unit(
          id: 'i_u1',
          title: '经历叙述',
          description: '',
          lessons: [Lesson(id: 'i_u1l1', title: '交代背景', exercises: [])],
        ),
      ],
    );
    expect(course.lessonPlace('i_u1l1'), '英语中级 · 经历叙述 · 交代背景 · i_u1l1');
    expect(
      fillDiagnosticRoute('/lesson/:lessonId', {'lessonId': 'i_u1l1'}),
      '/lesson/i_u1l1',
    );
    expect(
      fillDiagnosticRoute('/lesson/:lessonId/result', {'lessonId': 'i_u1l1'}),
      '/lesson/i_u1l1/result',
    );

    await log.rememberLesson(
      route: '/lesson/i_u1l1',
      lesson: course.lessonPlace('i_u1l1')!,
    );
    await log.setRoute('/lesson/i_u1l1/result');
    expect(log.lesson, contains('交代背景'));
    await log.setRoute('/lesson/:lessonId');
    expect(log.route, '/lesson/i_u1l1/result');

    await log.enqueueFeedback(note: '听不到', installId: 'install-1');
    final context = log.pending.single['context'] as Map<String, dynamic>;
    expect(context['lesson'], '英语中级 · 经历叙述 · 交代背景 · i_u1l1');
    expect(context['route'], '/lesson/i_u1l1/result');

    await log.setRoute('/');
    expect(log.lesson, isEmpty);
    expect(log.route, '/');
  });

  test('离开课时后反馈仍带当前课程名，课内不覆盖完整课名', () async {
    await log.rememberCourse('英语中级');
    await log.rememberLesson(
      route: '/lesson/i_u1l1',
      lesson: '英语中级 · 经历叙述 · 交代背景 · i_u1l1',
    );
    await log.rememberCourse('英语初级');
    expect(log.lesson, '英语中级 · 经历叙述 · 交代背景 · i_u1l1');

    await log.setRoute('/practice/pronunciation');
    await log.rememberLesson(
      route: '/practice/pronunciation',
      lesson: '英语初级 · 发音',
    );
    await log.rememberCourse('普通话入门');
    expect(log.lesson, '英语初级 · 发音');

    await log.setRoute('/');
    expect(log.lesson, '普通话入门');
    expect(log.lesson.contains('发音'), isFalse);
    expect(log.lesson.contains('i_u1l1'), isFalse);

    await log.enqueueFeedback(note: '听不到', installId: 'install-1');
    final context = log.pending.single['context'] as Map<String, dynamic>;
    expect(context['lesson'], '普通话入门');
    expect(context['route'], '/');
  });
}
