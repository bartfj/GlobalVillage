import 'dart:convert';

import 'package:global_village_server/api.dart';
import 'package:global_village_server/auth_service.dart';
import 'package:global_village_server/inmemory_accounts_repo.dart';
import 'package:global_village_server/report_repo.dart';
import 'package:global_village_server/sync_repo.dart';
import 'package:image/image.dart' as image;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  const adminToken = 'admin-secret';

  Future<Response> send(
    Handler handler,
    String method,
    String path, {
    Object? body,
    String? bearer,
    Map<String, String>? headers,
  }) async {
    final encoded = body is String
        ? body
        : (body == null ? null : jsonEncode(body));
    return handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        body: encoded,
        headers: {
          if (encoded != null) 'content-type': 'application/json',
          if (bearer != null) 'authorization': 'Bearer $bearer',
          ...?headers,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> json(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, dynamic>;

  Map<String, Object?> sample({String id = 'reportid01', String? answer}) => {
    'reportId': id,
    'note': '听不到',
    'context': {
      'appVersion': '0.8.32',
      'os': 'android',
      'osVersion': '13',
      'lesson': '英语中级 · 经历叙述 · 交代背景 · i_u1l1',
      'accessToken': 'secret-token',
    },
    'events': [
      {
        'at': '2026-01-01T00:00:00.000Z',
        'level': 'error',
        'kind': 'tts',
        'message': 'play failed',
        'answer': answer,
        'token': 'secret-token',
      },
    ],
  };

  Handler open({String? token, ReportRepo? reports}) => buildRouter(
    InMemoryAccountsRepo(),
    AuthService('test-secret'),
    syncRepo: InMemorySyncRepo(),
    reportRepo: reports,
    adminToken: token,
  );

  final jpeg = base64Encode(image.encodeJpg(image.Image(width: 1, height: 1)));
  Map<String, Object?> withScreenshot() => {
    'reportId': 'screenshot01',
    'events': [],
    'screenshot': jpeg,
  };

  test('仅截图反馈可发送，图片仅出现在受保护的详情，重试不覆盖', () async {
    final handler = open(token: adminToken);
    const upload = '/v1/reports/with-screenshot';
    const detail = '/admin/api/reports/screenshot01';
    final first = await send(handler, 'POST', upload, body: withScreenshot());
    expect(first.statusCode, 200);
    expect(await json(first), {
      'ok': true,
      'duplicate': false,
      'reportId': 'screenshot01',
      'screenshotAccepted': true,
    });

    final retry = await send(
      handler,
      'POST',
      upload,
      body: {...withScreenshot(), 'note': '重复发送的备注'},
    );
    expect(retry.statusCode, 200);
    expect(await json(retry), {
      'ok': true,
      'duplicate': true,
      'reportId': 'screenshot01',
      'screenshotAccepted': true,
    });

    expect((await send(handler, 'GET', detail)).statusCode, 401);
    final listed = await json(
      await send(handler, 'GET', '/admin/api/reports', bearer: adminToken),
    );
    expect(listed['reports'], hasLength(1));
    expect(listed['reports'][0], isNot(contains('screenshot')));
    final response = await json(
      await send(handler, 'GET', detail, bearer: adminToken),
    );
    expect(response['report']['screenshot'], jpeg);
    expect(response['report']['note'], isNull);
    expect(response['report']['events'], isEmpty);
  });

  test('截图不能复用文字报告的编号，也不能覆盖另一张图片', () async {
    final reports = InMemoryReportRepo();
    final handler = open(reports: reports);
    const upload = '/v1/reports/with-screenshot';
    final textOnly = await send(
      handler,
      'POST',
      '/v1/reports',
      body: sample(id: 'screenshot01'),
    );
    expect(textOnly.statusCode, 200);
    final sameId = await send(handler, 'POST', upload, body: withScreenshot());
    expect(sameId.statusCode, 409);
    expect((await json(sameId))['code'], 'report_conflict');
    expect((await reports.get('screenshot01'))!.screenshot, isNull);

    final picture = {...withScreenshot(), 'reportId': 'screenshot02'};
    expect(
      (await send(handler, 'POST', upload, body: picture)).statusCode,
      200,
    );
    final replacement = await send(
      handler,
      'POST',
      upload,
      body: {
        ...picture,
        'screenshot': base64Encode(
          image.encodeJpg(image.Image(width: 2, height: 1)),
        ),
      },
    );
    expect(replacement.statusCode, 409);
    expect(
      base64Encode((await reports.get('screenshot02'))!.screenshot!),
      jpeg,
    );
  });

  test('截图上报拒绝缺失、无效和超限图片', () async {
    final reports = InMemoryReportRepo();
    final handler = open(token: adminToken, reports: reports);
    final jpegBytes = base64Decode(jpeg);
    final oversized = base64Encode(List.filled(512 * 1024 + 1, 0));
    final overwide = base64Encode(
      image.encodeJpg(image.Image(width: 1921, height: 1)),
    );
    for (final invalid in [
      null,
      'not-base64!',
      base64Encode([0xff, 0xd8, 0xff, 0xd9]),
      base64Encode(jpegBytes.sublist(0, jpegBytes.length - 2)),
      oversized,
      overwide,
    ]) {
      final response = await send(
        handler,
        'POST',
        '/v1/reports/with-screenshot',
        body: {...withScreenshot(), 'screenshot': invalid},
      );
      expect(response.statusCode, 400);
    }
    expect(await reports.list(), isEmpty);
  });

  test('截图接口按流限制没有 Content-Length 的请求', () async {
    final handler = open();
    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/reports/with-screenshot'),
        body: Stream<List<int>>.fromIterable([
          List.filled(512 * 1024, 32),
          List.filled(256 * 1024 + 1, 32),
        ]),
      ),
    );
    expect(response.statusCode, 413);
  });

  test('持失效令牌的截图上报等待重新登录，游客可匿名上报', () async {
    final reports = InMemoryReportRepo();
    final handler = open(reports: reports);
    const upload = '/v1/reports/with-screenshot';
    final unauthorized = await send(
      handler,
      'POST',
      upload,
      body: withScreenshot(),
      bearer: 'expired-or-invalid',
    );
    expect(unauthorized.statusCode, 401);
    expect(await reports.list(), isEmpty);
    final anonymous = await send(
      handler,
      'POST',
      upload,
      body: withScreenshot(),
    );
    expect(anonymous.statusCode, 200);
    expect((await reports.list()).single.accountId, isNull);
  });

  test('截图反馈只能绑定与有效令牌一致的原账号', () async {
    final reports = InMemoryReportRepo();
    final handler = open(reports: reports);
    final registered = await json(
      await send(
        handler,
        'POST',
        '/v1/auth/register',
        body: {
          'email': 'a@example.com',
          'password': 'secret6',
          'displayName': 'Ann',
        },
      ),
    );
    final accountId = registered['account']['accountId'] as String;
    final access = registered['accessToken'] as String;
    Future<Response> submit({String? bearer, required String account}) => send(
      handler,
      'POST',
      '/v1/reports/with-screenshot',
      body: {
        ...withScreenshot(),
        'context': {'accountId': account},
      },
      bearer: bearer,
    );

    expect((await submit(account: accountId)).statusCode, 401);
    expect((await submit(account: 'other', bearer: access)).statusCode, 401);
    expect(await reports.list(), isEmpty);

    expect((await submit(account: accountId, bearer: access)).statusCode, 200);
    expect((await reports.list()).single.accountId, accountId);

    final guestReplay = await send(
      handler,
      'POST',
      '/v1/reports/with-screenshot',
      body: withScreenshot(),
    );
    expect(guestReplay.statusCode, 409);
    expect((await reports.list()).single.accountId, accountId);
  });

  test('合法上报 200，相同 id 不重复入库', () async {
    final reports = InMemoryReportRepo();
    final handler = open(token: adminToken, reports: reports);
    final first = await send(handler, 'POST', '/v1/reports', body: sample());
    expect(first.statusCode, 200);
    expect((await json(first))['duplicate'], isFalse);

    final second = await send(handler, 'POST', '/v1/reports', body: sample());
    expect(second.statusCode, 200);
    expect((await json(second))['duplicate'], isTrue);

    final listed = await json(
      await send(handler, 'GET', '/admin/api/reports', bearer: adminToken),
    );
    expect(listed['reports'], hasLength(1));
    expect(listed['reports'][0]['lesson'], '英语中级 · 经历叙述 · 交代背景 · i_u1l1');
    expect(listed['reports'][0]['accountLabel'], '未登录');
    expect(listed['reports'][0]['platform'], 'android');
    expect(listed['reports'][0]['osVersion'], '13');
    final detail = await json(
      await send(
        handler,
        'GET',
        '/admin/api/reports/reportid01',
        bearer: adminToken,
      ),
    );
    final text = jsonEncode(detail);
    expect(text.contains('secret-token'), isFalse);
    expect(text.contains('answer'), isFalse);
    expect(detail['report']['events'][0]['message'], 'play failed');
    expect(
      detail['report']['context']['lesson'],
      '英语中级 · 经历叙述 · 交代背景 · i_u1l1',
    );
    expect(detail['report']['accountLabel'], '未登录');
    expect(detail['report']['platform'], 'android');
    expect(detail['report']['osVersion'], '13');
  });

  test('超大请求体拒绝', () async {
    final handler = open(token: adminToken);
    final response = await send(
      handler,
      'POST',
      '/v1/reports',
      body: 'x' * (maxReportBodyBytes + 1),
    );
    expect(response.statusCode, 413);
  });

  test('无管理口令不能读列表，未开启后台时路径不存在', () async {
    final guarded = open(token: adminToken);
    expect((await send(guarded, 'GET', '/admin/api/reports')).statusCode, 401);

    final closed = open();
    expect(
      (await send(
        closed,
        'GET',
        '/admin/api/reports',
        bearer: adminToken,
      )).statusCode,
      404,
    );
  });

  test('有效 access token 写入账号，无效 token 仍接收且不绑定账号', () async {
    final handler = open(token: adminToken);
    final registered = await json(
      await send(
        handler,
        'POST',
        '/v1/auth/register',
        body: {
          'email': 'a@example.com',
          'password': 'secret6',
          'displayName': 'Ann',
        },
      ),
    );
    final accountId = registered['account']['accountId'] as String;
    final access = registered['accessToken'] as String;

    expect(
      (await send(
        handler,
        'POST',
        '/v1/reports',
        body: sample(id: 'reportid02'),
        bearer: access,
      )).statusCode,
      200,
    );
    expect(
      (await send(
        handler,
        'POST',
        '/v1/reports',
        body: sample(id: 'reportid03'),
        bearer: 'not-a-token',
      )).statusCode,
      200,
    );

    final listed = await json(
      await send(handler, 'GET', '/admin/api/reports', bearer: adminToken),
    );
    final byId = {
      for (final report in listed['reports'] as List)
        (report as Map)['reportId'] as String: report,
    };
    expect(byId['reportid02']!['accountId'], accountId);
    expect(byId['reportid02']!['accountLabel'], 'a@example.com · Ann');
    expect(byId['reportid03']!['accountId'], isNull);
    expect(byId['reportid03']!['accountLabel'], '未登录');
  });

  test('内存仓储新实例为空，超过 500 条丢掉最旧的', () async {
    final first = InMemoryReportRepo();
    expect(await first.insert(_stored('kept')), isTrue);
    expect(await InMemoryReportRepo().list(), isEmpty);

    final repo = InMemoryReportRepo();
    for (var i = 0; i <= maxStoredReports; i++) {
      expect(await repo.insert(_stored('r$i')), isTrue);
    }
    expect(await repo.get('r0'), isNull);
    expect(await repo.get('r$maxStoredReports'), isNotNull);
    expect(
      await repo.list(limit: maxStoredReports),
      hasLength(maxStoredReports),
    );
  });
}

ClientReport _stored(String id) => ClientReport(
  reportId: id,
  receivedAt: DateTime.utc(2026, 1, 1),
  appVersion: '0.8.32',
  context: const {'appVersion': '0.8.32'},
  events: const [
    {
      'at': '2026-01-01T00:00:00.000Z',
      'level': 'error',
      'kind': 'tts',
      'message': 'play failed',
    },
  ],
);
