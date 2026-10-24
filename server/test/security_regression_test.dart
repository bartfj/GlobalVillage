import 'dart:convert';

import 'package:global_village_server/api.dart';
import 'package:global_village_server/auth_service.dart';
import 'package:global_village_server/inmemory_accounts_repo.dart';
import 'package:global_village_server/sync_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('拒绝恶意课号和无法供后台解析的进度，不改动已有快照', () async {
    final handler = buildRouter(
      InMemoryAccountsRepo(),
      AuthService('test-secret'),
      syncRepo: InMemorySyncRepo(),
    );
    Future<Response> send(
      String method,
      String path, {
      String? token,
      Object? body,
    }) async => handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {
          'content-type': 'application/json',
          if (token != null) 'authorization': 'Bearer $token',
        },
        body: body == null ? null : jsonEncode(body),
      ),
    );
    final registration = await send(
      'POST',
      '/v1/auth/register',
      body: {
        'email': 'review@example.com',
        'displayName': 'Review',
        'password': 'secret6',
      },
    );
    final registered = jsonDecode(await registration.readAsString()) as Map;
    final token = registered['accessToken'] as String;
    for (final progress in [
      {
        '<img src=x onerror="alert(1)">': {'completed': true, 'score': 100},
      },
      {
        'u1l1': {'score': 'not a number'},
      },
      {
        'u1l1': {'completedAt': {}},
      },
    ]) {
      final response = await send(
        'PUT',
        '/v1/sync',
        token: token,
        body: {
          'clientUpdatedAt': 1,
          'payload': {'schemaVersion': 1, 'progress': progress},
        },
      );
      expect(response.statusCode, 400);
    }
    expect((await send('GET', '/v1/sync', token: token)).statusCode, 204);
  });
}
