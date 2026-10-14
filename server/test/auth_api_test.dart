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

    test('手机号注册成功，默认显示名为学员', () async {
      final response = await post('/v1/auth/register', {
        'phone': '+8613800138000',
        'password': 'secret6',
      });
      expect(response.statusCode, 200);
      final body = await json(response);
      expect(body['account']['phone'], '+8613800138000');
      expect(body['account']['displayName'], '学员');
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
      });
      expect(response.statusCode, 400);
      expect((await json(response))['code'], 'weak_password');
    });

    test('重复邮箱返回 409', () async {
      await post('/v1/auth/register', {
        'email': 'a@example.com',
        'password': 'secret6',
      });
      final response = await post('/v1/auth/register', {
        'email': 'a@example.com',
        'password': 'secret6',
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
      });
    });

    test('邮箱密码登录成功', () async {
      final response = await post('/v1/auth/login', {
        'email': 'a@example.com',
        'password': 'secret6',
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
      final registered = await json(await post('/v1/auth/register', {
        'email': 'a@example.com',
        'password': 'secret6',
      }));
      final response = await post('/v1/auth/refresh', {
        'refreshToken': registered['refreshToken'],
      });
      expect(response.statusCode, 200);
      expect((await json(response))['accessToken'], isNotEmpty);
    });

    test('access token 不能当 refresh token 用', () async {
      final registered = await json(await post('/v1/auth/register', {
        'email': 'a@example.com',
        'password': 'secret6',
      }));
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
}
