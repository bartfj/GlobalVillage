import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:global_village_server/accounts_repo.dart';
import 'package:global_village_server/api.dart';
import 'package:global_village_server/auth_service.dart';
import 'package:global_village_server/inmemory_accounts_repo.dart';
import 'package:global_village_server/sync_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  const adminToken = 'admin-secret';

  Future<Response> send(
    Handler handler,
    String method,
    String path, {
    Map<String, Object?>? body,
    String? bearer,
  }) async => handler(
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

  Handler open({String? token}) => buildRouter(
    InMemoryAccountsRepo(),
    AuthService('test-secret'),
    syncRepo: InMemorySyncRepo(),
    adminToken: token,
  );

  test('未设置 ADMIN_TOKEN 时后台路径为 404', () async {
    final handler = open();
    expect((await send(handler, 'GET', '/admin')).statusCode, 404);
    expect(
      (await send(
        handler,
        'GET',
        '/admin/api/accounts',
        bearer: adminToken,
      )).statusCode,
      404,
    );
  });

  test('错误口令 401，正确口令列出账号且不含密码哈希', () async {
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
    final denied = await send(
      handler,
      'GET',
      '/admin/api/accounts',
      bearer: registered['accessToken'] as String,
    );
    expect(denied.statusCode, 401);

    final listed = await send(
      handler,
      'GET',
      '/admin/api/accounts',
      bearer: adminToken,
    );
    expect(listed.statusCode, 200);
    final body = await json(listed);
    final text = jsonEncode(body);
    expect(text.contains('passwordHash'), false);
    expect(text.contains('password_hash'), false);
    expect(text.contains('passwordPlain'), false);
    expect(body['accounts'][0]['email'], 'a@example.com');
    expect(body['accounts'][0]['password'], 'secret6');
    expect(registered['account'].containsKey('password'), false);
  });

  test('停用后登录、刷新和同步失败，恢复后原 token 可用', () async {
    final handler = open(token: adminToken);
    final registered = await json(
      await send(
        handler,
        'POST',
        '/v1/auth/register',
        body: {
          'phone': '13500000000',
          'password': 'secret6',
          'displayName': 'Ann',
        },
      ),
    );
    final id = registered['account']['accountId'] as String;
    final access = registered['accessToken'] as String;
    final refresh = registered['refreshToken'] as String;

    expect(
      (await send(
        handler,
        'POST',
        '/admin/api/accounts/$id/disable',
        bearer: adminToken,
      )).statusCode,
      200,
    );
    expect(
      (await send(
        handler,
        'POST',
        '/v1/auth/login',
        body: {
          'phone': '13500000000',
          'password': 'secret6',
          'displayName': 'Ann',
        },
      )).statusCode,
      401,
    );
    expect(
      (await send(
        handler,
        'POST',
        '/v1/auth/refresh',
        body: {'refreshToken': refresh},
      )).statusCode,
      401,
    );
    expect(
      (await send(handler, 'GET', '/v1/sync', bearer: access)).statusCode,
      401,
    );

    expect(
      (await send(
        handler,
        'POST',
        '/admin/api/accounts/$id/enable',
        bearer: adminToken,
      )).statusCode,
      200,
    );
    expect(
      (await send(handler, 'GET', '/v1/sync', bearer: access)).statusCode,
      204,
    );
  });

  test('重置密码后旧 token 失效，新密码可登录且版本增加', () async {
    final handler = open(token: adminToken);
    final registered = await json(
      await send(
        handler,
        'POST',
        '/v1/auth/register',
        body: {
          'email': 'b@example.com',
          'password': 'secret6',
          'displayName': 'Ann',
        },
      ),
    );
    final id = registered['account']['accountId'] as String;
    final access = registered['accessToken'] as String;
    final refresh = registered['refreshToken'] as String;

    final reset = await json(
      await send(
        handler,
        'POST',
        '/admin/api/accounts/$id/password',
        bearer: adminToken,
        body: {'password': 'new-secret'},
      ),
    );
    expect(reset.containsKey('password'), false);
    expect(reset['credentialVersion'], 2);
    final afterReset = await json(
      await send(handler, 'GET', '/admin/api/accounts/$id', bearer: adminToken),
    );
    expect(afterReset['account']['password'], 'new-secret');

    expect(
      (await send(handler, 'GET', '/v1/sync', bearer: access)).statusCode,
      401,
    );
    expect(
      (await send(
        handler,
        'POST',
        '/v1/auth/refresh',
        body: {'refreshToken': refresh},
      )).statusCode,
      401,
    );
    final login = await send(
      handler,
      'POST',
      '/v1/auth/login',
      body: {'email': 'b@example.com', 'password': 'new-secret'},
    );
    expect(login.statusCode, 200);
  });

  test('删除账号与同步快照后无法再登录', () async {
    final handler = open(token: adminToken);
    final registered = await json(
      await send(
        handler,
        'POST',
        '/v1/auth/register',
        body: {
          'email': 'c@example.com',
          'password': 'secret6',
          'displayName': 'Ann',
        },
      ),
    );
    final id = registered['account']['accountId'] as String;
    final access = registered['accessToken'] as String;
    expect(
      (await send(
        handler,
        'PUT',
        '/v1/sync',
        bearer: access,
        body: {
          'clientUpdatedAt': 1,
          'payload': {
            'schemaVersion': 1,
            'progress': {
              'u1l1': {'completed': true, 'score': 80},
              'sa_u1l1': {'completed': true, 'score': 90},
            },
            'rewards': {'a': 'u1l1'},
            'track': {'selected': 'sanskrit'},
          },
        },
      )).statusCode,
      200,
    );

    final detail = await json(
      await send(handler, 'GET', '/admin/api/accounts/$id', bearer: adminToken),
    );
    expect(detail['progress']['english'][0]['lessonId'], 'u1l1');
    expect(detail['progress']['sanskrit'][0]['lessonId'], 'sa_u1l1');
    expect(detail['account'].containsKey('passwordHash'), false);
    expect(detail['account']['password'], 'secret6');

    expect(
      (await send(
        handler,
        'DELETE',
        '/admin/api/accounts/$id',
        bearer: adminToken,
      )).statusCode,
      204,
    );
    expect(
      (await send(
        handler,
        'GET',
        '/admin/api/accounts/$id',
        bearer: adminToken,
      )).statusCode,
      404,
    );
    expect(
      (await send(
        handler,
        'POST',
        '/v1/auth/login',
        body: {
          'email': 'c@example.com',
          'password': 'secret6',
          'displayName': 'Ann',
        },
      )).statusCode,
      401,
    );
  });

  test('两个账号的进度合并后写回两边', () async {
    final handler = open(token: adminToken);
    final first = await json(
      await send(
        handler,
        'POST',
        '/v1/auth/register',
        body: {
          'email': 'left@example.com',
          'password': 'secret6',
          'displayName': 'Ann',
        },
      ),
    );
    final second = await json(
      await send(
        handler,
        'POST',
        '/v1/auth/register',
        body: {
          'phone': '13600000000',
          'password': 'secret6',
          'displayName': 'Ann',
        },
      ),
    );
    final idA = first['account']['accountId'] as String;
    final idB = second['account']['accountId'] as String;
    final accessA = first['accessToken'] as String;
    final accessB = second['accessToken'] as String;

    expect(
      (await send(
        handler,
        'PUT',
        '/v1/sync',
        bearer: accessA,
        body: {
          'clientUpdatedAt': 10,
          'payload': {
            'schemaVersion': 1,
            'progress': {
              'u1l1': {'completed': true, 'score': 80, 'completedAt': 1},
            },
            'rewards': {'attempt-a': 'u1l1'},
            'track': {'selected': 'english', 'updatedAt': 10},
          },
        },
      )).statusCode,
      200,
    );
    expect(
      (await send(
        handler,
        'PUT',
        '/v1/sync',
        bearer: accessB,
        body: {
          'clientUpdatedAt': 20,
          'payload': {
            'schemaVersion': 1,
            'progress': {
              'u1l1': {'completed': true, 'score': 100, 'completedAt': 2},
              'sa_u1l1': {'completed': true, 'score': 90, 'completedAt': 3},
            },
            'rewards': {'attempt-b': 'sa_u1l1'},
            'track': {'selected': 'sanskrit', 'updatedAt': 20},
          },
        },
      )).statusCode,
      200,
    );

    final merged = await json(
      await send(
        handler,
        'POST',
        '/admin/api/sync',
        bearer: adminToken,
        body: {'sourceAccountId': idB, 'targetAccountId': idA},
      ),
    );
    expect(merged['lessonCount'], 2);
    expect(merged['targetAccountId'], idA);

    final source = await json(
      await send(handler, 'GET', '/v1/sync', bearer: accessB),
    );
    final target = await json(
      await send(handler, 'GET', '/v1/sync', bearer: accessA),
    );
    expect(source['payload']['progress'].containsKey('u1l1'), true);
    expect(source['payload']['progress'].containsKey('sa_u1l1'), true);
    expect(source['payload']['rewards'].containsKey('attempt-a'), false);
    expect(target['payload']['progress']['u1l1']['score'], 100);
    expect(target['payload']['progress']['sa_u1l1']['score'], 90);
    expect(target['payload']['rewards']['attempt-a'], 'u1l1');
    expect(target['payload']['rewards']['attempt-b'], 'sa_u1l1');
    expect(target['payload']['track']['selected'], 'sanskrit');
  });

  test('登录会补记上线前没有明文的密码，登录响应本身不含密码', () async {
    final auth = AuthService('test-secret');
    final repo = InMemoryAccountsRepo();
    final now = DateTime.now().toUtc();
    await repo.create(
      Account(
        accountId: newAccountId(),
        email: 'old@example.com',
        passwordHash: await auth.hashPassword('secret6'),
        displayName: 'Ann',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final handler = buildRouter(
      repo,
      auth,
      syncRepo: InMemorySyncRepo(),
      adminToken: adminToken,
    );

    final login = await send(
      handler,
      'POST',
      '/v1/auth/login',
      body: {'email': 'old@example.com', 'password': 'secret6'},
    );
    expect(login.statusCode, 200);
    final loginBody = await json(login);
    expect(loginBody['account'].containsKey('password'), false);

    final listed = await json(
      await send(handler, 'GET', '/admin/api/accounts', bearer: adminToken),
    );
    expect(listed['accounts'][0]['password'], 'secret6');

    final page = await send(handler, 'GET', '/admin');
    expect(await page.readAsString(), contains('>密码<'));
  });

  test('没有 cv 的旧 token 不能同步', () async {
    final handler = open(token: adminToken);
    final registered = await json(
      await send(
        handler,
        'POST',
        '/v1/auth/register',
        body: {
          'email': 'd@example.com',
          'password': 'secret6',
          'displayName': 'Ann',
        },
      ),
    );
    final id = registered['account']['accountId'] as String;
    final legacy = JWT(
      {'sub': id, 'typ': 'access'},
      issuer: 'global-village-server',
    ).sign(SecretKey('test-secret'), expiresIn: const Duration(minutes: 5));
    expect(
      (await send(handler, 'GET', '/v1/sync', bearer: legacy)).statusCode,
      401,
    );
  });
}
