import 'dart:convert';

import 'package:global_village_server/api.dart';
import 'package:global_village_server/auth_service.dart';
import 'package:global_village_server/inmemory_accounts_repo.dart';
import 'package:global_village_server/sync_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Handler handler;
  late String accessToken;

  Future<Response> request(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? bearer,
  }) async =>
      handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
          headers: {
            if (body != null) 'content-type': 'application/json',
            if (bearer != null) 'authorization': 'Bearer $bearer',
          },
        ),
      );

  Future<Map<String, dynamic>> json(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, dynamic>;

  setUp(() async {
    handler = buildRouter(
      InMemoryAccountsRepo(),
      AuthService('test-secret'),
      syncRepo: InMemorySyncRepo(),
    );
    final registered = await json(await request('POST', '/v1/auth/register', body: {
      'email': 'a@example.com',
      'password': 'secret6',
    }));
    accessToken = registered['accessToken'] as String;
  });

  test('未带 token 访问 sync 返回 401', () async {
    expect((await request('GET', '/v1/sync')).statusCode, 401);
    expect((await request('PUT', '/v1/sync', body: {})).statusCode, 401);
  });

  test('refresh token 不能当 access token 用', () async {
    final registered = await json(await request('POST', '/v1/auth/login', body: {
      'email': 'a@example.com',
      'password': 'secret6',
    }));
    final response = await request('GET', '/v1/sync',
        bearer: registered['refreshToken'] as String);
    expect(response.statusCode, 401);
  });

  test('首次拉取返回 204，上传后可取回', () async {
    expect((await request('GET', '/v1/sync', bearer: accessToken)).statusCode,
        204);

    final put = await request('PUT', '/v1/sync', bearer: accessToken, body: {
      'clientUpdatedAt': 1000,
      'payload': {
        'schemaVersion': 1,
        'clientUpdatedAt': 1000,
        'progress': {'l1': {'completed': true, 'score': 90}},
        'rewards': {'a1': 'l1'},
        'track': {'selected': 'zero'},
      },
    });
    expect(put.statusCode, 200);

    final get = await request('GET', '/v1/sync', bearer: accessToken);
    expect(get.statusCode, 200);
    final body = await json(get);
    expect(body['clientUpdatedAt'], 1000);
    expect(body['payload']['progress']['l1']['score'], 90);
    expect(body['payload']['rewards']['a1'], 'l1');
  });

  test('baseClientUpdatedAt 不一致返回 409', () async {
    await request('PUT', '/v1/sync', bearer: accessToken, body: {
      'clientUpdatedAt': 1000,
      'payload': {'schemaVersion': 1},
    });
    final conflict = await request('PUT', '/v1/sync', bearer: accessToken, body: {
      'clientUpdatedAt': 2000,
      'baseClientUpdatedAt': 999,
      'payload': {'schemaVersion': 1},
    });
    expect(conflict.statusCode, 409);
    final body = await json(conflict);
    expect(body['code'], 'sync_conflict');
    expect(body['currentClientUpdatedAt'], 1000);

    final ok = await request('PUT', '/v1/sync', bearer: accessToken, body: {
      'clientUpdatedAt': 2000,
      'baseClientUpdatedAt': 1000,
      'payload': {'schemaVersion': 1},
    });
    expect(ok.statusCode, 200);
  });

  test('快照按账号隔离', () async {
    await request('PUT', '/v1/sync', bearer: accessToken, body: {
      'clientUpdatedAt': 1000,
      'payload': {'schemaVersion': 1},
    });
    final other = await json(await request('POST', '/v1/auth/register', body: {
      'email': 'b@example.com',
      'password': 'secret6',
    }));
    expect(
      (await request('GET', '/v1/sync',
              bearer: other['accessToken'] as String))
          .statusCode,
      204,
    );
  });
}
