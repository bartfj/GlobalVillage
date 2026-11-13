import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pattern_training_fixture.dart';

Lesson parse(Map<String, dynamic>? training) => Lesson.fromJson({
  'id': 'l1',
  'title': 'Requests',
  'exercises': [],
  if (training != null) 'patternTraining': training,
});

void main() {
  test('actual beginner course has withdrawn all pilot metadata', () {
    final json =
        jsonDecode(
              File('assets/courses/course_beginner.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final course = Course.fromJson(json);
    final pilots = course.orderedLessons
        .where((l) => l.patternTraining != null)
        .toList();
    expect(pilots, isEmpty);
    expect(course.orderedLessons, hasLength(272));
  });
  test('legacy lessons remain const and parse without pattern training', () {
    const old = Lesson(id: 'old', title: 'Old', exercises: []);
    expect(old.id, 'old');
    expect(parse(null).exercises, isEmpty);
  });
  test(
    'pattern training is parsed with six learning exercises and examples',
    () {
      final dynamic lesson = parse(patternJson());
      final dynamic training = lesson.patternTraining;
      expect(training.id, 'mp_want');
      expect(training.version, 1);
      expect(training.suffix, '');
      expect(training.exercises, hasLength(6));
      expect(training.allExercises, hasLength(14));
      expect(training.examples, hasLength(3));
    },
  );
  final mutations = <String, void Function(Map<String, dynamic>)>{
    'invalid version': (p) => p['version'] = 0,
    'noninteger version': (p) => p['version'] = 1.5,
    'empty frame': (p) => p['frame'] = '  ',
    'empty prefix': (p) => p['prefix'] = ' ',
    'wrong example count': (p) => (p['examples'] as List).removeLast(),
    'wrong substitution count': (p) =>
        (p['substitution'] as List).add(p['substitution'][0]),
    'wrong recall count': (p) => (p['recall'] as List).removeLast(),
    'wrong transfer count': (p) => (p['transfer'] as List).clear(),
    'insufficient review': (p) =>
        p['review'] = (p['review'] as List).take(3).toList(),
    'wrong phase type': (p) => p['examples'][0]['type'] = 'translateInput',
    'duplicate exercise id': (p) =>
        p['review'][0]['id'] = p['examples'][0]['id'],
    'empty prompt': (p) => p['recall'][0]['prompt'] = ' ',
    'empty sentence': (p) => p['recall'][0]['sentence'] = '',
    'empty answer': (p) => p['recall'][0]['answer'] = '',
    'non-English exercise': (p) => p['review'][0]['language'] = 'chinese',
    'non-English frame': (p) => p['frame'] = '我想要',
    'incorrect bank tokens': (p) =>
        p['substitution'][0]['tokens'] = ['I', 'want', 'coffee'],
    'example missing prefix': (p) =>
        p['examples'][0]['sentence'] = 'We want tea.',
    'example missing suffix': (p) => p['suffix'] = ' please.',
    'example empty slot': (p) => p['examples'][0]['sentence'] = 'I want ',
  };
  for (final mutation in mutations.entries) {
    test('rejects ${mutation.key}', () {
      final json = patternJson();
      mutation.value(json);
      expect(() => parse(json), throwsFormatException);
    });
  }
  test(
    'bank normalization supports case, punctuation and curly apostrophes',
    () {
      final json = patternJson();
      json['substitution'][0]['answer'] = "I want o'clock.";
      json['substitution'][0]['tokens'] = ['i', 'WANT', 'o’clock!'];
      expect(() => parse(json), returnsNormally);
    },
  );
  test(
    'Chinese meaning slot instructions and prompts are valid teaching support',
    () {
      final json = patternJson();
      json['meaning'] = '我想要……';
      json['slotRule'] = '换成你想要的东西。';
      json['recall'][0]['prompt'] = '我想要茶。';
      json['recall'][0]['support'] = '想一想句型。';
      expect(() => parse(json), returnsNormally);
    },
  );
}
