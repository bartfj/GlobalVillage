import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/pattern_lesson.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise scenario(String answer, List<String> alternatives) =>
    Exercise.fromJson({
      'id': 'mp_test_scenario',
      'type': 'speaking',
      'speakingMode': 'scenario',
      'prompt': '你向服务员礼貌点一个三明治。',
      'sentence': answer,
      'answer': answer,
      'acceptedAnswers': alternatives,
    });

Map<String, dynamic> lessonJson() {
  final types = [
    'listeningChoice',
    'wordBank',
    'speaking',
    'translateInput',
    'speaking',
  ];
  final phases = ['listening', 'chunks', 'repeat', 'recall', 'scenario'];
  final exercises = <Map<String, dynamic>>[];
  for (var phase = 0; phase < 5; phase++) {
    for (var i = 0; i < 2; i++) {
      exercises.add({
        'id': 'mp_test_${phase}_$i',
        'type': types[phase],
        'prompt': '你叫汤姆，向同学介绍自己。',
        'sentence': 'I am Tom.',
        'answer': 'I am Tom.',
        if (phase == 0)
          'options': ['I am Tom.', 'I am Amy.', 'I am Lucy.', 'I am Li Ming.'],
        if (phase == 1) 'tokens': ['I am', 'Tom.'],
        if (phase == 4) 'speakingMode': 'scenario',
      });
    }
  }
  Map<String, dynamic> extra(String id, bool review) => {
    'id': id,
    'type': 'speaking',
    'prompt': '你叫汤姆，向同学介绍自己。',
    'sentence': 'I am Tom.',
    'answer': 'I am Tom.',
    if (review) 'speakingMode': 'scenario',
    'audioId': id,
  };
  return {
    'id': 'mp_test_lesson',
    'title': '介绍身份',
    'exercises': exercises,
    'patternLesson': {
      'id': 'mp_test',
      'version': 1,
      'kind': 'pattern',
      'frame': 'I am …',
      'meaning': '介绍自己的身份或状态。',
      'slotRule': '空位填姓名、身份或状态。',
      'limitations': ['本课只用 I。'],
      'dialogue': [
        {
          'speaker': 'Tom',
          'text': 'I am Tom.',
          'translation': '我是汤姆。',
          'audioId': 'mp_test_d1',
        },
        {
          'speaker': 'Amy',
          'text': 'I am Amy.',
          'translation': '我是艾米。',
          'audioId': 'mp_test_d2',
        },
      ],
      'vocabulary': [
        {'text': 'Tom', 'meaning': '汤姆（姓名）', 'audioId': 'mp_test_v1'},
      ],
      'examples': [
        for (var i = 0; i < 3; i++) extra('mp_test_example_$i', false),
      ],
      'review': [for (var i = 0; i < 4; i++) extra('mp_test_review_$i', true)],
      'phases': [
        for (var phase = 0; phase < 5; phase++)
          {
            'type': phases[phase],
            'exerciseIds': ['mp_test_${phase}_0', 'mp_test_${phase}_1'],
          },
      ],
      'patternIds': ['mp_test'],
    },
  };
}

void main() {
  test('scenario speaking accepts authored contractions strictly', () {
    final exercise = scenario('I would like a sandwich.', [
      "I'd like a sandwich.",
      'I would like a sandwich, please.',
      "I'd like a sandwich, please.",
    ]);
    expect(exercise.accepts('I’d like a sandwich, please!'), isTrue);
    expect(exercise.accepts('I want a sandwich.'), isFalse);
    expect(exercise.accepts('I would like two sandwiches.'), isFalse);
    expect(exercise.accepts('I would like a salad.'), isFalse);
    expect(exercise.accepts('sandwich'), isFalse);
  });

  test('legacy speaking preserves exact answer without new alternatives', () {
    final exercise = Exercise.fromJson({
      'id': 'old',
      'type': 'speaking',
      'prompt': 'Repeat',
      'sentence': 'I am Tom.',
      'answer': 'I am Tom.',
      'acceptedAnswers': ["I'm Tom."],
    });
    expect(exercise.accepts('I am Tom!'), isTrue);
    expect(exercise.accepts("I'm Tom."), isFalse);
    final lesson = Lesson.fromJson({
      'id': 'old',
      'title': 'Old',
      'exercises': [],
    });
    expect(lesson.patternTraining, isNull);
  });

  test('independent mother pattern pack exists and has sixteen lessons', () {
    final file = File('assets/courses/course_mother_pattern.json');
    expect(file.existsSync(), isTrue);
    final course = Course.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
    expect(course.id, 'motherPattern');
    expect(course.units, hasLength(4));
    expect(course.orderedLessons, hasLength(16));
    for (final lesson in course.orderedLessons) {
      expect(lesson.exercises, hasLength(10));
      expect(lesson.patternTraining, isNull);
    }
  });

  test(
    'lesson parses versioned metadata and four independent exercise IDs',
    () {
      final lesson = Lesson.fromJson(lessonJson());
      expect(lesson.patternLesson, isNotNull);
      expect(lesson.patternLesson!.independentExerciseIds, [
        'mp_test_3_0',
        'mp_test_3_1',
        'mp_test_4_0',
        'mp_test_4_1',
      ]);
      expect(
        lesson.patternLesson!.phaseForExercise('mp_test_4_0'),
        PatternPhaseType.scenario,
      );
    },
  );

  final mutations = <String, void Function(Map<String, dynamic>)>{
    'invalid version': (p) => p['patternLesson']['version'] = 0,
    'missing dialogue audio': (p) =>
        p['patternLesson']['dialogue'][0].remove('audioId'),
    'missing taught vocabulary': (p) => p['patternLesson']['vocabulary'] = [],
    'unknown phase reference': (p) =>
        p['patternLesson']['phases'][0]['exerciseIds'][0] = 'mp_absent',
    'duplicate phase reference': (p) =>
        p['patternLesson']['phases'][1]['exerciseIds'][0] = 'mp_test_0_0',
    'wrong phase type': (p) => p['exercises'][0]['type'] = 'speaking',
    'incorrect chunk tokens': (p) =>
        p['exercises'][2]['tokens'] = ['I am', 'Amy.'],
    'scenario without scenario mode': (p) =>
        p['exercises'][8].remove('speakingMode'),
    'insufficient review': (p) => p['patternLesson']['review'].removeLast(),
    'non-English answer': (p) => p['exercises'][8]['answer'] = '我是汤姆。',
    'duplicate supplementary exercise ID': (p) =>
        p['patternLesson']['review'][0]['id'] = 'mp_test_example_0',
    'empty accepted alternative': (p) =>
        p['exercises'][8]['acceptedAnswers'] = [''],
    'wrong stage count': (p) =>
        p['patternLesson']['phases'][0]['exerciseIds'].removeLast(),
    'scored exercises shuffled before phases': (p) {
      final exercises = p['exercises'] as List;
      final last = exercises.removeLast();
      exercises.insert(0, last);
    },
    'wrong prefix': (p) => p['patternLesson']['id'] = 'old_test',
  };
  for (final mutation in mutations.entries) {
    test('metadata rejects ${mutation.key}', () {
      final json = lessonJson();
      mutation.value(json);
      expect(() => Lesson.fromJson(json), throwsFormatException);
    });
  }
}
