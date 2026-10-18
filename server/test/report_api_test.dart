import 'dart:convert';

import 'package:global_village_server/api.dart';
import 'package:global_village_server/auth_service.dart';
import 'package:global_village_server/inmemory_accounts_repo.dart';
import 'package:global_village_server/report_repo.dart';
import 'package:global_village_server/sync_repo.dart';
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
        (report as Map)['reportId']: report['accountId'],
    };
    expect(byId['reportid02'], accountId);
    expect(byId['reportid03'], isNull);
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
