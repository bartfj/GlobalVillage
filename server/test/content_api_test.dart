import 'dart:async';
import 'dart:convert';

import 'package:global_village_server/api.dart';
import 'package:global_village_server/auth_service.dart';
import 'package:global_village_server/content_repo.dart';
import 'package:global_village_server/inmemory_accounts_repo.dart';
import 'package:global_village_server/sync_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../../test/mother_pattern_validation_fixture.dart';

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

  test('中文课程发布时拒绝不合格的选择题和词块题', () async {
    final handler = open();
    for (final id in ['chineseZero', 'chinese']) {
      final path = '/admin/api/content/packs/course/$id';
      Map<String, Object?> pack(Map<String, Object?> changes) => {
        'id': id,
        'language': 'chinese',
        'title': '中文',
        'units': [
          {
            'id': 'zh_fixture_unit',
            'title': '拼音',
            'description': 'Pinyin',
            'lessons': [
              {
                'id': 'zh_fixture_lesson',
                'title': '声调',
                'exercises': [
                  {
                    'id': 'zh_fixture_choice',
                    'type': 'translateChoice',
                    'language': 'chinese',
                    'prompt': 'Choose: mother',
                    'sentence': 'mā',
                    'answer': 'mā',
                    'options': ['mā', 'má', 'mǎ', 'mà'],
                    ...changes,
                  },
                ],
              },
            ],
          },
        ],
      };
      for (final invalid in <Map<String, Object?>>[
        {
          'options': ['mā'],
        },
        {
          'type': 'listeningChoice',
          'options': ['mā', 'má', 'mǎ'],
        },
        {
          'options': ['mā', 'mā', 'mǎ', 'mà'],
        },
        {
          'options': ['mā', 'ma\u0304', 'mǎ', 'mà'],
        },
        {
          'options': ['mā', 'ma1', 'mǎ', 'mà'],
        },
        {
          'options': ['mā', 'má', ' ', 'mà'],
        },
        {
          'options': ['mā', 'má', '\u200E', 'mà'],
        },
        {
          'options': ['mā', 'má', 'má\u200E', 'mà'],
        },
        {
          'options': ['mi', 'má', 'mǎ', 'mà'],
        },
        {
          'type': 'wordBank',
          'tokens': ['mā'],
          'tokenSeparator': '',
        },
        {
          'type': 'wordBank',
          'answer': '你好',
          'tokens': ['好', '你'],
          'tokenSeparator': '',
        },
        {
          'type': 'wordBank',
          'answer': '好好好',
          'tokens': ['好', '好好'],
          'tokenSeparator': '',
        },
      ]) {
        expect(
          (await send(
            handler,
            'PUT',
            path,
            bearer: adminToken,
            body: pack(invalid),
          )).statusCode,
          200,
        );
        final publish = await send(
          handler,
          'POST',
          '$path/publish',
          bearer: adminToken,
        );
        expect(publish.statusCode, 400, reason: '$id: $invalid');
        expect((await json(publish))['message'], contains('zh_fixture_choice'));
        expect(
          (await send(
            handler,
            'GET',
            '/v1/content/packs/course/$id',
          )).statusCode,
          404,
        );
      }

      expect(
        (await send(
          handler,
          'PUT',
          path,
          bearer: adminToken,
          body: pack({
            'options': ['ma\u0304', 'má', 'mǎ', 'mà'],
          }),
        )).statusCode,
        200,
      );
      expect(
        (await send(
          handler,
          'POST',
          '$path/publish',
          bearer: adminToken,
        )).statusCode,
        200,
      );
      expect(
        (await send(handler, 'GET', '/v1/content/packs/course/$id')).statusCode,
        200,
      );
    }
  });

  test('发布遇到并发替换草稿时保留原发布版本', () async {
    final repo = _PausedDraftReadRepo();
    final handler = open(content: repo);
    const path = '/admin/api/content/packs/course/beginner';
    const publicPath = '/v1/content/packs/course/beginner';
    Future<Response> save(Map<String, Object?> body) =>
        send(handler, 'PUT', path, bearer: adminToken, body: body);

    final initial = course(title: '第一版');
    expect((await save(initial)).statusCode, 200);
    expect(
      (await send(
        handler,
        'POST',
        '$path/publish',
        bearer: adminToken,
      )).statusCode,
      200,
    );

    expect((await save(course(title: '第二版'))).statusCode, 200);
    repo.pauseNextRead = true;
    final publishing = send(
      handler,
      'POST',
      '$path/publish',
      bearer: adminToken,
    );
    await repo.snapshotRead.future;
    try {
      // The editor may store a draft whose shape would fail validation.
      expect((await save({'id': 'beginner', 'title': '坏'})).statusCode, 200);
    } finally {
      repo.allowRead.complete();
    }

    final conflict = await publishing;
    expect(conflict.statusCode, 409);
    expect((await json(conflict))['code'], 'draft_changed');
    expect(await json(await send(handler, 'GET', publicPath)), initial);
    final manifest = await json(
      await send(handler, 'GET', '/v1/content/manifest'),
    );
    expect(manifest['documents'][0]['revision'], 1);
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

  test('motherPattern publishes, downloads metadata, and withdraws', () async {
    final handler = open();
    final pack = independentPack(root: '..');
    const path = '/admin/api/content/packs/course/motherPattern';
    expect(
      (await send(
        handler,
        'PUT',
        path,
        bearer: adminToken,
        body: pack,
      )).statusCode,
      200,
    );
    final publish = await send(
      handler,
      'POST',
      '$path/publish',
      bearer: adminToken,
    );
    expect(publish.statusCode, 200);
    final manifest = await json(
      await send(handler, 'GET', '/v1/content/manifest'),
    );
    expect(manifest['documents'][0]['id'], 'course/motherPattern');
    final downloaded = await json(
      await send(handler, 'GET', '/v1/content/packs/course/motherPattern'),
    );
    expect(downloaded, pack);
    firstLesson(pack)['exercises'][8]['sentence'] = 'I want tea.';
    expect(
      (await send(
        handler,
        'PUT',
        path,
        bearer: adminToken,
        body: pack,
      )).statusCode,
      200,
    );
    final invalid = await json(
      await send(handler, 'POST', '$path/publish', bearer: adminToken),
    );
    expect(invalid['code'], 'invalid_content');
    expect(
      await json(
        await send(handler, 'GET', '/v1/content/packs/course/motherPattern'),
      ),
      downloaded,
    );
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
      (await json(
        await send(handler, 'GET', '/v1/content/manifest'),
      ))['documents'],
      isEmpty,
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

class _PausedDraftReadRepo extends InMemoryContentRepo {
  bool pauseNextRead = false;
  final snapshotRead = Completer<void>();
  final allowRead = Completer<void>();

  @override
  Future<StoredDocument?> getDocument(String packId) async {
    final document = await super.getDocument(packId);
    if (pauseNextRead) {
      pauseNextRead = false;
      snapshotRead.complete();
      await allowRead.future;
    }
    return document;
  }
}
