import 'dart:convert';

import 'package:global_village_server/api.dart';
import 'package:global_village_server/auth_service.dart';
import 'package:global_village_server/inmemory_accounts_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Handler handler;

  setUp(() {
    handler = buildRouter(InMemoryAccountsRepo(), AuthService('test-secret'));
  });

  Future<Response> post(String path, Map<String, Object?> body) async =>
      handler(
        Request(
          'POST',
          Uri.parse('http://localhost$path'),
          body: jsonEncode(body),
          headers: {'content-type': 'application/json'},
        ),
      );

  Future<Map<String, dynamic>> json(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, dynamic>;

  test('GET /v1/health 无需鉴权', () async {
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/v1/health')),
    );
    expect(response.statusCode, 200);
    final body = await json(response);
    expect(body['ok'], true);
    expect(body['service'], 'global_village_server');
  });

  group('register', () {
    test('邮箱注册成功并返回双 token', () async {
      final response = await post('/v1/auth/register', {
        'email': 'a@example.com',
        'password': 'secret6',
        'displayName': 'Ann',
      });
      expect(response.statusCode, 200);
      final body = await json(response);
      expect(body['account']['email'], 'a@example.com');
      expect(body['account']['displayName'], 'Ann');
      expect(body['account']['accountId'], isNotEmpty);
      expect(body['accessToken'], isNotEmpty);
      expect(body['refreshToken'], isNotEmpty);
    });

    test('缺昵称或超长返回 400', () async {
      final missing = await post('/v1/auth/register', {
        'phone': '+8613800138000',
        'password': 'secret6',
      });
      expect(missing.statusCode, 400);
      expect((await json(missing))['code'], 'invalid_display_name');

      final tooLong = await post('/v1/auth/register', {
        'email': 'long@example.com',
        'password': 'secret6',
        'displayName': '这是一个超过十二个字的昵称',
      });
      expect(tooLong.statusCode, 400);
      expect((await json(tooLong))['code'], 'invalid_display_name');
    });

    test('邮箱与手机号都缺返回 400', () async {
      final response = await post('/v1/auth/register', {'password': 'secret6'});
      expect(response.statusCode, 400);
      expect((await json(response))['code'], 'missing_identifier');
    });

    test('密码太短返回 400', () async {
      final response = await post('/v1/auth/register', {
        'email': 'a@example.com',
        'password': '12345',
        'displayName': 'Ann',
      });
      expect(response.statusCode, 400);
      expect((await json(response))['code'], 'weak_password');
    });

    test('重复邮箱返回 409', () async {
      await post('/v1/auth/register', {
        'email': 'a@example.com',
        'password': 'secret6',
        'displayName': 'Ann',
      });
      final response = await post('/v1/auth/register', {
        'email': 'a@example.com',
        'password': 'secret6',
        'displayName': 'Ann',
      });
      expect(response.statusCode, 409);
      expect((await json(response))['code'], 'email_taken');
    });
  });

  group('login', () {
    setUp(() async {
      await post('/v1/auth/register', {
        'email': 'a@example.com',
        'password': 'secret6',
        'displayName': 'Ann',
      });
    });

    test('邮箱密码登录成功', () async {
      final response = await post('/v1/auth/login', {
        'email': 'a@example.com',
        'password': 'secret6',
        'displayName': 'Ann',
      });
      expect(response.statusCode, 200);
      expect((await json(response))['account']['email'], 'a@example.com');
    });

    test('密码错误与账号不存在统一 401', () async {
      for (final email in ['a@example.com', 'ghost@example.com']) {
        final response = await post('/v1/auth/login', {
          'email': email,
          'password': 'wrong-pass',
        });
        expect(response.statusCode, 401);
        expect((await json(response))['code'], 'invalid_credentials');
      }
    });
  });

  group('refresh / logout', () {
    test('refresh token 换取新 access token', () async {
      final registered = await json(
        await post('/v1/auth/register', {
          'email': 'a@example.com',
          'password': 'secret6',
          'displayName': 'Ann',
        }),
      );
      final response = await post('/v1/auth/refresh', {
        'refreshToken': registered['refreshToken'],
      });
      expect(response.statusCode, 200);
      expect((await json(response))['accessToken'], isNotEmpty);
    });

    test('access token 不能当 refresh token 用', () async {
      final registered = await json(
        await post('/v1/auth/register', {
          'email': 'a@example.com',
          'password': 'secret6',
          'displayName': 'Ann',
        }),
      );
      final response = await post('/v1/auth/refresh', {
        'refreshToken': registered['accessToken'],
      });
      expect(response.statusCode, 401);
    });

    test('无效 refresh token 返回 401', () async {
      final response = await post('/v1/auth/refresh', {
        'refreshToken': 'not-a-token',
      });
      expect(response.statusCode, 401);
    });

    test('logout 幂等返回 204', () async {
      final response = await post('/v1/auth/logout', {'refreshToken': 'x'});
      expect(response.statusCode, 204);
    });
  });

  group('profile', () {
    Future<Response> send(
      String method,
      String path, {
      Map<String, Object?>? body,
      String? bearer,
    }) async {
      return handler(
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
    }

    test('未登录访问资料返回 401', () async {
      expect((await send('GET', '/v1/auth/me')).statusCode, 401);
      expect(
        (await send(
          'PATCH',
          '/v1/auth/profile',
          body: {'displayName': '新昵称'},
        )).statusCode,
        401,
      );
    });

    test('注册写入昵称，修改后 GET /me 读到新昵称', () async {
      final registered = await json(
        await post('/v1/auth/register', {
          'email': 'a@example.com',
          'password': 'secret6',
          'displayName': 'Ann',
        }),
      );
      expect(registered['account']['displayName'], 'Ann');
      expect(registered['account']['createdAt'], isNotEmpty);
      final token = registered['accessToken'] as String;

      final patched = await json(
        await send(
          'PATCH',
          '/v1/auth/profile',
          bearer: token,
          body: {'displayName': ' 新昵称 '},
        ),
      );
      expect(patched['account']['displayName'], '新昵称');

      final me = await json(await send('GET', '/v1/auth/me', bearer: token));
      expect(me['account']['displayName'], '新昵称');
      expect(me['account']['email'], 'a@example.com');
      expect(me['account']['createdAt'], registered['account']['createdAt']);
    });
  });
}
