import 'dart:convert';

import 'package:global_village_server/api.dart';
import 'package:global_village_server/auth_service.dart';
import 'package:global_village_server/content_repo.dart';
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
    Object? body,
    String? bearer,
    String? contentType,
  }) async {
    final encoded = body is List<int>
        ? body
        : body == null
        ? null
        : utf8.encode(body is String ? body : jsonEncode(body));
    return await handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        body: encoded,
        headers: {
          if (encoded != null)
            'content-type': contentType ?? 'application/json',
          if (bearer != null) 'authorization': 'Bearer $bearer',
        },
      ),
    );
  }

  Future<Map<String, dynamic>> json(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, dynamic>;

  Handler open({ContentRepo? content}) => buildRouter(
    InMemoryAccountsRepo(),
    AuthService('test-secret'),
    syncRepo: InMemorySyncRepo(),
    contentRepo: content ?? InMemoryContentRepo(),
    adminToken: adminToken,
  );

  Map<String, Object?> course({String title = '初级'}) => {
    'id': 'beginner',
    'title': title,
    'units': [
      {
        'id': 'u1',
        'title': '问候',
        'description': '打招呼',
        'lessons': [
          {
            'id': 'u1l1',
            'title': '你好',
            'exercises': [
              {
                'id': 'u1l1e1',
                'type': 'translateChoice',
                'prompt': '你好',
                'sentence': 'Hello.',
                'answer': 'Hello',
                'options': ['Hello', 'Bye', 'Thanks', 'Sorry'],
              },
            ],
          },
        ],
      },
    ],
  };

  test('未发布时清单为空，草稿不会被公开下载', () async {
    final handler = open();
    final manifest = await json(
      await send(handler, 'GET', '/v1/content/manifest'),
    );
    expect(manifest['documents'], isEmpty);
    expect(manifest['files'], isEmpty);

    final saved = await send(
      handler,
      'PUT',
      '/admin/api/content/packs/course/beginner',
      bearer: adminToken,
      body: course(),
    );
    expect(saved.statusCode, 200);
    final after = await json(
      await send(handler, 'GET', '/v1/content/manifest'),
    );
    expect(after['documents'], isEmpty);
    expect(
      (await send(
        handler,
        'GET',
        '/v1/content/packs/course/beginner',
      )).statusCode,
      404,
    );
  });

  test('错误口令不能改草稿，发布后可下载且修订号增加，撤回后清单消失', () async {
    final handler = open();
    expect(
      (await send(
        handler,
        'PUT',
        '/admin/api/content/packs/course/beginner',
        bearer: 'nope',
        body: course(),
      )).statusCode,
      401,
    );

    expect(
      (await send(
        handler,
        'PUT',
        '/admin/api/content/packs/course/beginner',
        bearer: adminToken,
        body: course(title: '第一版'),
      )).statusCode,
      200,
    );
    final first = await json(
      await send(
        handler,
        'POST',
        '/admin/api/content/packs/course/beginner/publish',
        bearer: adminToken,
      ),
    );
    expect(first['revision'], 1);
    expect(first['published'], true);

    final manifest = await json(
      await send(handler, 'GET', '/v1/content/manifest'),
    );
    expect(manifest['documents'], hasLength(1));
    expect(manifest['documents'][0]['id'], 'course/beginner');
    expect(manifest['documents'][0]['revision'], 1);

    final downloaded = await json(
      await send(handler, 'GET', '/v1/content/packs/course/beginner'),
    );
    expect(downloaded['title'], '第一版');

    expect(
      (await send(
        handler,
        'PUT',
        '/admin/api/content/packs/course/beginner',
        bearer: adminToken,
        body: course(title: '第二版'),
      )).statusCode,
      200,
    );
    final second = await json(
      await send(
        handler,
        'POST',
        '/admin/api/content/packs/course/beginner/publish',
        bearer: adminToken,
      ),
    );
    expect(second['revision'], 2);
    final again = await json(
      await send(handler, 'GET', '/v1/content/packs/course/beginner'),
    );
    expect(again['title'], '第二版');

    final withdrawn = await json(
      await send(
        handler,
        'POST',
        '/admin/api/content/packs/course/beginner/unpublish',
        bearer: adminToken,
      ),
    );
    expect(withdrawn['published'], false);
    final empty = await json(
      await send(handler, 'GET', '/v1/content/manifest'),
    );
    expect(empty['documents'], isEmpty);
    expect(
      (await send(
        handler,
        'GET',
        '/v1/content/packs/course/beginner',
      )).statusCode,
      404,
    );
  });

  test('后台页面包含内容包模块', () async {
    final handler = open();
    final page = await send(handler, 'GET', '/admin');
    final html = await page.readAsString();
    expect(html, contains('内容包'));
    expect(html, contains('data-view="content"'));
    expect(html, contains('data-view="audio"'));
  });

  test('结构不合法不能发布', () async {
    final handler = open();
    expect(
      (await send(
        handler,
        'PUT',
        '/admin/api/content/packs/course/beginner',
        bearer: adminToken,
        body: {'id': 'beginner', 'title': '缺单元'},
      )).statusCode,
      200,
    );
    final published = await json(
      await send(
        handler,
        'POST',
        '/admin/api/content/packs/course/beginner/publish',
        bearer: adminToken,
      ),
    );
    expect(published['code'], 'invalid_content');
    final manifest = await json(
      await send(handler, 'GET', '/v1/content/manifest'),
    );
    expect(manifest['documents'], isEmpty);
  });

  test('音频草稿发布后可按字节下载，撤回后公开地址消失', () async {
    final handler = open();
    const path = '/admin/api/content/files/audio/listening/u1l1e6.mp3';
    final bytes = [0x49, 0x44, 0x33, 9, 8, 7];
    expect(
      (await send(
        handler,
        'PUT',
        path,
        bearer: adminToken,
        body: bytes,
        contentType: 'audio/mpeg',
      )).statusCode,
      200,
    );
    expect(
      (await send(
        handler,
        'GET',
        '/v1/content/files/audio/listening/u1l1e6.mp3',
      )).statusCode,
      404,
    );
    final published = await json(
      await send(handler, 'POST', '$path/publish', bearer: adminToken),
    );
    expect(published['revision'], 1);
    expect(published['published'], true);

    final file = await send(
      handler,
      'GET',
      '/v1/content/files/audio/listening/u1l1e6.mp3',
    );
    expect(file.statusCode, 200);
    expect(await file.read().expand((chunk) => chunk).toList(), bytes);

    final manifest = await json(
      await send(handler, 'GET', '/v1/content/manifest'),
    );
    expect(manifest['files'][0]['path'], 'audio/listening/u1l1e6.mp3');
    expect(manifest['files'][0]['bytes'], bytes.length);

    expect(
      (await send(
        handler,
        'POST',
        '$path/unpublish',
        bearer: adminToken,
      )).statusCode,
      200,
    );
    expect(
      (await send(
        handler,
        'GET',
        '/v1/content/files/audio/listening/u1l1e6.mp3',
      )).statusCode,
      404,
    );
  });
}
