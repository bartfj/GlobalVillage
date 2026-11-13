import 'dart:convert';
import 'dart:io';

import 'package:global_village_server/content_validate.dart';
import 'package:test/test.dart';

import '../../test/pattern_training_fixture.dart';

Map<String, dynamic> course(Map<String, dynamic>? training) => {
  'id': 'beginner',
  'title': 'Legacy',
  'units': [
    {
      'id': 'u1',
      'title': 'Unit',
      'description': 'Unit',
      'lessons': [
        {
          'id': 'l1',
          'title': 'Lesson',
          'exercises': [
            {
              'id': 'legacy',
              'type': 'speaking',
              'prompt': '',
              'sentence': '',
              'answer': '',
            },
          ],
          if (training != null) 'patternTraining': training,
        },
      ],
    },
  ],
};
String? validate(Map<String, dynamic>? p) =>
    validateContentPack('course/beginner', jsonEncode(course(p)));
void main() {
  test('bundled beginner course with all six pilots remains publishable', () {
    final raw = File('../assets/courses/course_beginner.json')
        .readAsStringSync();
    final content = jsonDecode(raw) as Map<String, dynamic>;
    final pilots = [
      for (final unit in content['units'] as List)
        for (final lesson in unit['lessons'] as List)
          if (lesson['patternTraining'] != null) lesson['patternTraining'],
    ];
    expect(pilots, hasLength(6));
    expect(validateContentPack('course/beginner', raw), isNull);
  });
  test(
    'legacy course and valid optional pattern training remain publishable',
    () {
      expect(validate(null), isNull);
      expect(validate(patternJson()), isNull);
    },
  );
  final mutations = <String, void Function(Map<String, dynamic>)>{
    'version': (p) => p['version'] = 0,
    'integer version': (p) => p['version'] = 1.1,
    'text': (p) => p['slotRule'] = ' ',
    'language': (p) => p['review'][0]['language'] = 'chinese',
    'English content': (p) => p['frame'] = '我想要',
    'example count': (p) => (p['examples'] as List).removeLast(),
    'substitution count': (p) => (p['substitution'] as List).clear(),
    'recall count': (p) => (p['recall'] as List).clear(),
    'transfer count': (p) => (p['transfer'] as List).clear(),
    'review count': (p) => p['review'] = [],
    'type': (p) => p['recall'][0]['type'] = 'wordBank',
    'unique ids': (p) => p['review'][0]['id'] = p['examples'][0]['id'],
    'nonempty prompt': (p) => p['recall'][0]['prompt'] = '',
    'tokens': (p) => p['substitution'][0]['tokens'] = ['Wrong'],
    'prefix': (p) => p['examples'][0]['sentence'] = 'We want tea.',
    'suffix': (p) => p['suffix'] = ' please.',
  };
  for (final mutation in mutations.entries) {
    test('publishing rejects invalid pattern ${mutation.key}', () {
      final p = patternJson();
      mutation.value(p);
      expect(validate(p), isNotNull);
    });
  }
  test('wrong object shape is rejected', () {
    final c = course(null);
    c['units'][0]['lessons'][0]['patternTraining'] = 'bad';
    expect(validateContentPack('course/beginner', jsonEncode(c)), isNotNull);
  });
  test('bank normalization matches app punctuation and apostrophes', () {
    final p = patternJson();
    p['substitution'][0]['answer'] = "I want o'clock.";
    p['substitution'][0]['tokens'] = ['i', 'WANT', 'o’clock!'];
    expect(validate(p), isNull);
  });
  test(
    'Chinese teaching instructions coexist with English target sentences',
    () {
      final p = patternJson();
      p['meaning'] = '我想要……';
      p['slotRule'] = '放入名词。';
      p['recall'][0]['prompt'] = '我想要茶。';
      p['recall'][0]['support'] = '用母句型来回答。';
      expect(validate(p), isNull);
    },
  );
}
