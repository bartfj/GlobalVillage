import 'dart:convert';

import 'package:global_village_server/content_validate.dart';
import 'package:test/test.dart';

import '../../test/mother_pattern_validation_fixture.dart';
import '../../test/pattern_training_fixture.dart';

void main() {
  test('independent pack is registered and valid for publication', () {
    expect(
      validateContentPack(
        'course/motherPattern',
        jsonEncode(independentPack(root: '..')),
      ),
      isNull,
    );
  });
  for (final mutation in independentPackMutations.entries) {
    test('independent publication rejects ${mutation.key}', () {
      final pack = independentPack(root: '..');
      mutation.value(pack);
      final error = validateContentPack(
        'course/motherPattern',
        jsonEncode(pack),
      );
      expect(error, isNot('未知内容包'));
      expect(error, isNotNull);
    });
  }
  for (final entity in ['unit', 'lesson', 'exercise', 'metadata']) {
    test('ordinary publication rejects independent $entity', () {
      final pack = independentPack(root: '..')..['id'] = 'beginner';
      final lesson = firstLesson(pack);
      for (final u in pack['units']) {
        for (final l in u['lessons']) {
          l.remove('patternLesson');
        }
      }
      pack['units'] = [
        {
          'id': 'u1',
          'title': 'Unit',
          'description': 'Unit',
          'lessons': [
            {
              'id': 'u1l1',
              'title': 'Lesson',
              'exercises': [
                {
                  'id': 'u1l1e1',
                  'type': 'speaking',
                  'prompt': '',
                  'sentence': 'Hello.',
                  'answer': 'Hello.',
                },
              ],
            },
          ],
        },
      ];
      final ordinary = pack['units'][0]['lessons'][0];
      switch (entity) {
        case 'unit':
          pack['units'][0]['id'] = 'mp_u1';
        case 'lesson':
          ordinary['id'] = 'mp_u1l1';
        case 'exercise':
          ordinary['exercises'][0]['id'] = 'mp_u1l1_e1';
        case 'metadata':
          ordinary['patternLesson'] = lesson;
      }
      expect(
        validateContentPack('course/beginner', jsonEncode(pack)),
        isNotNull,
      );
    });
  }
  test('legacy training supplemental mp IDs are compatible', () {
    final pack = {
      'id': 'beginner',
      'title': 'Legacy',
      'units': [
        {
          'id': 'u1',
          'title': 'Unit',
          'description': 'Unit',
          'lessons': [
            {
              'id': 'u1l1',
              'title': 'Lesson',
              'exercises': [],
              'patternTraining': patternJson(),
            },
          ],
        },
      ],
    };
    expect(validateContentPack('course/beginner', jsonEncode(pack)), isNull);
  });
  test('canonical audio normalization allows punctuation and authored contractions', () {
    final p = independentPack(root: '..');
    firstLesson(p)['exercises'][8]['sentence'] = '  i AM happy! ';
    expect(validateContentPack('course/motherPattern', jsonEncode(p)), isNull);
  });
}
