import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/sources/content_cache.dart';
import 'package:english_village/data/sources/content_documents.dart';
import 'package:english_village/data/sources/course_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  String courseJson(String title) => jsonEncode({
    'id': 'zero',
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
              },
            ],
          },
        ],
      },
    ],
  });

  test('有缓存用缓存，没有缓存用内置，坏 JSON 丢掉并回退', () async {
    final docs = _MemoryDocuments({'course/zero': courseJson('缓存课')});
    var bundleReads = 0;
    Future<String> bundle() async {
      bundleReads++;
      return courseJson('内置课');
    }

    final cached = await readOverlaidText(
      documents: docs,
      packId: 'course/zero',
      bundle: bundle,
    );
    expect(jsonDecode(cached)['title'], '缓存课');
    expect(bundleReads, 0);

    docs.packs['course/zero'] = null;
    final bundled = await readOverlaidText(
      documents: docs,
      packId: 'course/zero',
      bundle: bundle,
    );
    expect(jsonDecode(bundled)['title'], '内置课');
    expect(bundleReads, 1);
    expect(docs.dropped, isEmpty);

    docs.packs['course/zero'] = '{';
    final fallback = await readOverlaidText(
      documents: docs,
      packId: 'course/zero',
      bundle: bundle,
    );
    expect(jsonDecode(fallback)['title'], '内置课');
    expect(docs.dropped, ['course/zero']);
    expect(bundleReads, 2);
  });

  test('课程形状不合法时不用覆盖', () async {
    final docs = _MemoryDocuments({'course/zero': '{"id":"zero","title":"坏"}'});
    final loader = CourseLoader(
      assetBundle: _MemoryBundle({
        CourseTrack.zero.assetPath: courseJson('内置课'),
      }),
      documents: docs,
    );

    final course = await loader.load(CourseTrack.zero);
    expect(course.title, '内置课');
    expect(docs.dropped, ['course/zero']);
  });

  test('清单里的内容会缓存，坏正文不缓存，撤回后删除', () async {
    final root = await Directory.systemTemp.createTemp('gv-content');
    addTearDown(() => root.delete(recursive: true));
    final published = courseJson('远程课');
    final bytes = utf8.encode(published);
    final digest = sha256.convert(bytes).toString();
    var mode = 'published';
    final client = _ScriptedClient((request) async {
      if (mode == 'down') throw const SocketException('down');
      if (request.url.path.endsWith('/manifest')) {
        if (mode == 'empty') {
          return http.Response(jsonEncode({'documents': [], 'files': []}), 200);
        }
        if (mode == 'bad') {
          final bad = utf8.encode('[]');
          return http.Response(
            jsonEncode({
              'documents': [
                {
                  'id': 'course/beginner',
                  'revision': 1,
                  'sha256': sha256.convert(bad).toString(),
                  'bytes': bad.length,
                },
              ],
              'files': [],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'documents': [
              {
                'id': 'course/zero',
                'revision': 2,
                'sha256': digest,
                'bytes': bytes.length,
              },
            ],
            'files': [],
          }),
          200,
        );
      }
      if (mode == 'bad') return http.Response.bytes(utf8.encode('[]'), 200);
      return http.Response.bytes(bytes, 200);
    });
    final cache = ContentCache(
      root: root,
      client: client,
      readBaseUrl: () => 'http://example.test/v1',
    );
    addTearDown(cache.close);

    await cache.sync();
    final stored = await cache.packJson('course/zero');
    expect(jsonDecode(stored!)['title'], '远程课');

    mode = 'down';
    await cache.sync();
    expect(jsonDecode((await cache.packJson('course/zero'))!)['title'], '远程课');

    mode = 'empty';
    await cache.sync();
    expect(await cache.packJson('course/zero'), isNull);

    mode = 'bad';
    await cache.sync();
    expect(await cache.packJson('course/beginner'), isNull);
  });
}

class _MemoryDocuments implements ContentDocuments {
  _MemoryDocuments(this.packs);

  final Map<String, String?> packs;
  final dropped = <String>[];

  @override
  Future<String?> packJson(String packId) async => packs[packId];

  @override
  Future<String?> audioFilePath(String relativePath) async => null;

  @override
  Future<void> dropPack(String packId) async {
    dropped.add(packId);
    packs.remove(packId);
  }
}

class _MemoryBundle extends CachingAssetBundle {
  _MemoryBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw Exception('missing $key');
    final bytes = Uint8List.fromList(utf8.encode(text));
    return ByteData.sublistView(bytes);
  }
}

class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this.handle);

  final Future<http.Response> Function(http.BaseRequest request) handle;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handle(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
