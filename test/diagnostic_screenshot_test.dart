import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  late AuthState auth;

  // The uploader forwards already-normalized bytes from the photo picker.
  final screenshot = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
  const accountA = AuthState(userKey: 'online:account-a', accessToken: 'a');
  const accountB = AuthState(userKey: 'online:account-b', accessToken: 'b');

  http.Response acknowledged(http.Request request, {bool duplicate = false}) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    return http.Response(
      jsonEncode({
        'ok': true,
        'duplicate': duplicate,
        'reportId': body['reportId'],
        'screenshotAccepted': true,
      }),
      200,
    );
  }

  DiagnosticUploader makeUploader(
    MockClient client, {
    String Function()? readBaseUrl,
  }) => DiagnosticUploader(
    log: log,
    api: ReportApi(
      readBaseUrl: readBaseUrl ?? () => 'http://localhost:8787/v1',
      client: client,
    ),
    settings: SettingsStore(),
    readAuth: () => auth,
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('diagnostic_screenshot');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(DiagnosticLog.boxName);
    await Hive.openBox<String>(SettingsStore.boxName);
    log = DiagnosticLog(os: 'android', osVersion: '14');
    auth = accountA;
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'screenshot-only feedback survives restart and waits for its account',
    () async {
      String? reportId;
      var screenshotCalls = 0;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path == '/v1/reports') {
          expect(request.headers['authorization'], 'Bearer b');
          expect(body['note'], '普通反馈');
          expect(body, isNot(contains('screenshot')));
          return http.Response('{"ok":true}', 200);
        }
        expect(request.url.path, '/v1/reports/with-screenshot');
        expect(request.headers['authorization'], 'Bearer a');
        expect(body['screenshot'], base64Encode(screenshot));
        expect(body['note'], isNull);
        expect(body['events'], isEmpty);
        reportId ??= body['reportId'] as String;
        expect(body['reportId'], reportId);
        screenshotCalls++;
        return screenshotCalls == 1
            ? http.Response('offline', 503)
            : acknowledged(request, duplicate: true);
      });

      expect(
        await makeUploader(
          client,
        ).submitFeedback(note: '', screenshot: screenshot),
        isFalse,
      );
      await Hive.close();
      await Hive.openBox<String>(DiagnosticLog.boxName);
      await Hive.openBox<String>(SettingsStore.boxName);
      log = DiagnosticLog(os: 'android', osVersion: '14');
      expect(log.pending.single['reportId'], reportId);

      auth = accountB;
      final restarted = makeUploader(client);
      expect(await restarted.submitFeedback(note: '普通反馈'), isTrue);
      expect(screenshotCalls, 1);
      expect(log.pending.single['reportId'], reportId);

      auth = const AuthState(userKey: 'online:account-a');
      expect(await restarted.flush(), isFalse);
      expect(screenshotCalls, 1);

      auth = accountA;
      expect(await restarted.flush(), isTrue);
      expect(screenshotCalls, 2);
      expect(log.pending, isEmpty);
    },
  );

  test(
    'a guest screenshot stays anonymous and needs an explicit server acknowledgment',
    () async {
      auth = const AuthState(userKey: 'guest');
      var calls = 0;
      final uploader = makeUploader(
        MockClient((request) async {
          expect(request.url.path, '/v1/reports/with-screenshot');
          expect(request.headers, isNot(contains('authorization')));
          calls++;
          return switch (calls) {
            1 => http.Response('<html>Proxy fallback</html>', 200),
            2 => http.Response('{"ok":true}', 200),
            3 => http.Response(
              '{"ok":true,"reportId":"another","screenshotAccepted":true}',
              200,
            ),
            _ => acknowledged(request),
          };
        }),
      );
      expect(
        await uploader.submitFeedback(note: '', screenshot: screenshot),
        isFalse,
      );
      expect(log.pending, hasLength(1));
      auth = accountB;
      expect(await uploader.flush(), isFalse);
      expect(log.pending, hasLength(1));
      expect(await uploader.flush(), isFalse);
      expect(log.pending, hasLength(1));
      expect(await uploader.flush(), isTrue);
      expect(log.pending, isEmpty);
    },
  );

  test(
    'a guest screenshot waits for its original server after restart',
    () async {
      auth = const AuthState(userKey: 'guest');
      var baseUrl = 'https://original.example/v1/';
      final destinations = <Uri>[];
      final client = MockClient((request) async {
        destinations.add(request.url);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          body.keys,
          unorderedEquals([
            'reportId',
            'note',
            'context',
            'events',
            'screenshot',
          ]),
        );
        expect(request.headers, isNot(contains('authorization')));
        return destinations.length == 1
            ? http.Response('offline', 503)
            : acknowledged(request);
      });
      expect(
        await makeUploader(
          client,
          readBaseUrl: () => baseUrl,
        ).submitFeedback(note: '', screenshot: screenshot),
        isFalse,
      );

      await Hive.close();
      await Hive.openBox<String>(DiagnosticLog.boxName);
      await Hive.openBox<String>(SettingsStore.boxName);
      log = DiagnosticLog(os: 'android', osVersion: '14');
      final restarted = makeUploader(client, readBaseUrl: () => baseUrl);
      auth = accountB;
      baseUrl = 'https://different.example/v1';
      expect(await restarted.flush(), isFalse);
      expect(destinations, hasLength(1));
      expect(log.pending, hasLength(1));

      baseUrl = 'https://original.example/v1';
      expect(await restarted.flush(), isTrue);
      expect(
        destinations,
        List.filled(
          2,
          Uri.parse('https://original.example/v1/reports/with-screenshot'),
        ),
      );
      expect(log.pending, isEmpty);
    },
  );

  test(
    'screenshot delivery uses the server it already checked before sending',
    () async {
      var urlReads = 0;
      final destinations = <Uri>[];
      final uploader = makeUploader(
        MockClient((request) async {
          destinations.add(request.url);
          return acknowledged(request);
        }),
        readBaseUrl: () => ++urlReads <= 2
            ? 'https://original.example/v1'
            : 'https://different.example/v1',
      );

      expect(
        await uploader.submitFeedback(note: '', screenshot: screenshot),
        isTrue,
      );
      expect(destinations.single.host, 'original.example');
      expect(urlReads, 2);
    },
  );

  test(
    'a failed screenshot upload cannot block text feedback from the same account',
    () async {
      final paths = <String>[];
      final uploader = makeUploader(
        MockClient((request) async {
          paths.add(request.url.path);
          return request.url.path.endsWith('/with-screenshot')
              ? http.Response('offline', 503)
              : http.Response('{"ok":true}', 200);
        }),
      );
      expect(
        await uploader.submitFeedback(note: '', screenshot: screenshot),
        isFalse,
      );
      paths.clear();
      expect(await uploader.submitFeedback(note: '普通反馈'), isTrue);
      expect(paths, ['/v1/reports']);
      expect(log.pending.single['screenshot'], base64Encode(screenshot));
    },
  );

  test(
    'a failed screenshot does not stop later screenshots in the same flush',
    () async {
      await log.enqueueFeedback(
        note: '较早反馈',
        installId: 'install',
        screenshot: screenshot,
        screenshotBaseUrl: 'http://localhost:8787/v1',
      );
      await log.enqueueFeedback(
        note: '另一条反馈',
        installId: 'install',
        screenshot: screenshot,
        screenshotBaseUrl: 'http://localhost:8787/v1',
      );
      final delivered = <String>[];
      final uploader = makeUploader(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final note = body['note'] as String;
          delivered.add(note);
          return delivered.length == 1
              ? http.Response('offline', 503)
              : acknowledged(request);
        }),
      );

      expect(await uploader.flush(), isFalse);
      expect(delivered, unorderedEquals(['较早反馈', '另一条反馈']));
      expect(log.pending.single['note'], delivered.first);
    },
  );

  test(
    'overlapping feedback and flush do not duplicate successful uploads',
    () async {
      final uploading = Completer<void>();
      final allowFirstResponse = Completer<void>();
      final ids = <String>[];
      final uploader = makeUploader(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          ids.add(body['reportId'] as String);
          if (!uploading.isCompleted) {
            uploading.complete();
            await allowFirstResponse.future;
          }
          return acknowledged(request);
        }),
      );

      final first = uploader.submitFeedback(note: '', screenshot: screenshot);
      await uploading.future;
      final text = uploader.submitFeedback(note: '普通反馈');
      final second = uploader.submitFeedback(
        note: '另一个截图',
        screenshot: screenshot,
      );
      final flush = uploader.flush();
      allowFirstResponse.complete();

      expect(
        await Future.wait([first, text, second, flush]),
        everyElement(isTrue),
      );
      expect(ids, hasLength(3));
      expect(ids.toSet(), hasLength(3));
      expect(log.pending, isEmpty);
    },
  );
}
