import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/sources/content_documents.dart';
import 'package:english_village/data/sources/content_cache.dart';
import 'package:english_village/data/sources/course_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'mother_pattern_validation_fixture.dart';
import 'pattern_training_fixture.dart';

void main() {
  test('independent registration loads the published pack', () async {
    final pack = independentPack()..['title'] = 'Published';
    final raw = jsonEncode(pack);
    final bytes = utf8.encode(raw);
    final root = await Directory.systemTemp.createTemp('mp-content-cache-');
    addTearDown(() => root.delete(recursive: true));
    final docs = ContentCache(
      root: root,
      readBaseUrl: () => 'http://example.test/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/manifest')) {
          return http.Response(
            jsonEncode({
              'documents': [
                {
                  'id': 'course/motherPattern',
                  'revision': 1,
                  'sha256': sha256.convert(bytes).toString(),
                  'bytes': bytes.length,
                },
              ],
              'files': [],
            }),
            200,
          );
        }
        return http.Response.bytes(bytes, 200);
      }),
    );
    addTearDown(docs.close);
    await docs.sync();
    final loader = CourseLoader(assetBundle: PackBundle(), documents: docs);
    expect((await loader.load(CourseTrack.motherPattern)).title, 'Published');
    expect(await docs.packJson('course/motherPattern'), raw);
  });
  for (final mutation in independentPackMutations.entries) {
    test('independent overlay falls back for ${mutation.key}', () async {
      final pack = independentPack()..['title'] = 'Malformed';
      mutation.value(pack);
      final docs = MemoryDocuments(jsonEncode(pack));
      final loaded = await CourseLoader(
        assetBundle: PackBundle(),
        documents: docs,
      ).load(CourseTrack.motherPattern);
      expect(loaded.title, '母句型听说');
      expect(docs.dropped, ['course/motherPattern']);
    });
  }
  for (final entity in ['unit', 'lesson', 'exercise', 'metadata', 'identity']) {
    test('ordinary overlay rejects independent $entity', () async {
      final p = ordinaryPack();
      final l = p['units'][0]['lessons'][0];
      switch (entity) {
        case 'unit':
          p['units'][0]['id'] = 'mp_u1';
        case 'lesson':
          l['id'] = 'mp_u1l1';
        case 'exercise':
          l['exercises'][0]['id'] = 'mp_u1l1_e1';
        case 'metadata':
          l['exercises'] = firstLesson(independentPack())['exercises'];
          l['patternLesson'] = firstPattern(independentPack());
        case 'identity':
          p['id'] = 'beginner';
      }
      final docs = MemoryDocuments(jsonEncode(p));
      final loaded = await CourseLoader(
        assetBundle: PackBundle(),
        documents: docs,
      ).load(CourseTrack.zero);
      expect(loaded.title, 'Bundled ordinary');
      expect(docs.dropped, ['course/zero']);
    });
  }
  test(
    'cached legacy training remains parseable without independent metadata',
    () async {
      final pack = ordinaryPack();
      pack['units'][0]['lessons'][0]['patternTraining'] = patternJson();
      final docs = MemoryDocuments(jsonEncode(pack));
      final course = await CourseLoader(
        assetBundle: PackBundle(),
        documents: docs,
      ).load(CourseTrack.zero);
      expect(course.orderedLessons.single.patternTraining, isNotNull);
      expect(course.orderedLessons.single.patternLesson, isNull);
      expect(docs.dropped, isEmpty);
    },
  );
}

Map<String, dynamic> ordinaryPack() => {
  'id': 'zero',
  'title': 'Published ordinary',
  'units': [
    {
      'id': 'z_u1',
      'title': 'Unit',
      'description': 'Unit',
      'lessons': [
        {
          'id': 'z_u1l1',
          'title': 'Lesson',
          'exercises': [
            {
              'id': 'z_u1l1e1',
              'type': 'speaking',
              'prompt': 'Repeat',
              'sentence': 'Hello.',
              'answer': 'Hello.',
            },
          ],
        },
      ],
    },
  ],
};

class MemoryDocuments implements ContentDocuments {
  MemoryDocuments(this.raw);
  final String raw;
  final dropped = <String>[];
  @override
  Future<String?> packJson(String packId) async => raw;
  @override
  Future<String?> audioFilePath(String relativePath) async => null;
  @override
  Future<void> dropPack(String packId) async {
    dropped.add(packId);
  }
}

class PackBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final pack = key == CourseTrack.motherPattern.assetPath
        ? independentPack()
        : (ordinaryPack()..['title'] = 'Bundled ordinary');
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(jsonEncode(pack))),
    );
  }
}
