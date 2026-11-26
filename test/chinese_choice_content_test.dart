import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/skill_practice.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readAsset(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

bool _isChoice(Exercise exercise) =>
    exercise.type == ExerciseType.translateChoice ||
    exercise.type == ExerciseType.listeningChoice;

List<String> _expectedAlternatives(String answer) => switch (answer) {
  'mā' || 'má' || 'mǎ' || 'mà' => ['mā', 'má', 'mǎ', 'mà'],
  'bā' || 'bá' || 'bǎ' || 'bà' => ['bā', 'bá', 'bǎ', 'bà'],
  '谢谢' || '再见' => ['你好', '谢谢', '再见', '不客气'],
  '一' || '二' || '三' => ['一', '二', '三', '四'],
  _ => throw ArgumentError.value(answer),
};

void main() {
  final courses = [
    Course.fromJson(_readAsset('assets/courses/course_chinese_zero.json')),
    Course.fromJson(_readAsset('assets/courses/course_chinese.json')),
  ];
  final lessons = [for (final course in courses) ...course.orderedLessons];
  final byId = {
    for (final lesson in lessons)
      for (final e in lesson.exercises) e.id: e,
  };

  test(
    'single-block questions preserve their answers as meaningful choices',
    () {
      const expectedAnswers = {
        'zh_u1l1e5': 'mā',
        'zh_u1l1e6': 'má',
        'zh_u1l1e7': 'mǎ',
        'zh_u1l2e5': 'bā',
        'zh_u1l2e6': 'bá',
        'zh_u1l2e7': 'bǎ',
        'zh_u1l3e5': 'mā',
        'zh_u1l3e6': 'mǎ',
        'zh_u1l3e7': 'bā',
        'zh_u1l4e5': 'má',
        'zh_u1l4e6': 'mà',
        'zh_u1l4e7': 'bá',
        'zh_u2l1e6': '谢谢',
        'zh_u2l1e7': '再见',
        'zh_u2l3e6': '再见',
        'zh_u2l4e5': '谢谢',
        'zh_u3l1e5': '一',
        'zh_u3l1e6': '二',
        'zh_u3l1e7': '三',
        'zh_u3l3e5': '一',
        'zh_u3l3e6': '三',
        'zh_u3l4e5': '二',
      };
      for (final entry in expectedAnswers.entries) {
        final exercise = byId[entry.key]!;
        expect(
          exercise.type,
          ExerciseType.translateChoice,
          reason: exercise.id,
        );
        expect(exercise.answer, entry.value, reason: exercise.id);
        expect(
          exercise.options,
          unorderedEquals(_expectedAlternatives(entry.value)),
          reason: exercise.id,
        );
        expect(exercise.support, isNull, reason: exercise.id);
        expect(exercise.tokens, isEmpty, reason: exercise.id);
      }
    },
  );

  test(
    'Chinese courses and drills offer four distinct choices with one accepted answer',
    () {
      final tones = SkillPracticeBank.fromJson(
        _readAsset('assets/practice/chineseTones.json'),
      );
      final characters = SkillPracticeBank.fromJson(
        _readAsset('assets/practice/chineseCharacters.json'),
      );
      final sources = [
        for (final course in courses)
          (
            course.id,
            course.orderedLessons.expand((lesson) => lesson.exercises),
          ),
        (tones.skill.name, tones.exercises),
        (characters.skill.name, characters.exercises),
      ];
      final counts = <int>[];
      for (final (name, exercises) in sources) {
        final choices = exercises.where(_isChoice).toList();
        counts.add(choices.length);
        for (final exercise in choices) {
          final reason = '$name/${exercise.id}';
          expect(exercise.options, hasLength(4), reason: reason);
          final normalized = exercise.options
              .map(exercise.normalizeInput)
              .toSet();
          expect(normalized, hasLength(4), reason: reason);
          expect(normalized, isNot(contains('')), reason: reason);
          expect(exercise.options, contains(exercise.answer), reason: reason);
          expect(
            exercise.options.where(exercise.accepts),
            hasLength(1),
            reason: reason,
          );
        }
        for (final exercise in exercises.where(
          (e) => e.type == ExerciseType.wordBank,
        )) {
          final reason = '$name/${exercise.id}';
          final normalized = exercise.tokens
              .map(exercise.normalizeInput)
              .toSet();
          expect(normalized, isNot(contains('')), reason: reason);
          expect(normalized.length, greaterThanOrEqualTo(2), reason: reason);
          expect(
            exercise.tokens.join(exercise.tokenSeparator),
            exercise.answer,
            reason: reason,
          );
        }
      }
      expect(counts, [28, 58, 27, 50]);
    },
  );

  test(
    'each block of Chinese course choices uses distinct answer positions',
    () {
      for (final lesson in lessons) {
        final positions = lesson.exercises
            .where(_isChoice)
            .map((exercise) => exercise.options.indexOf(exercise.answer))
            .toList();
        for (var i = 0; i < positions.length; i += 4) {
          final block = positions.skip(i).take(4).toList();
          expect(
            block.toSet(),
            hasLength(block.length),
            reason: '${lesson.id} block ${i ~/ 4 + 1}',
          );
        }
      }
    },
  );
}
