import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:flutter_test/flutter_test.dart';

void _assertExerciseShape(Lesson lesson) {
  expect(lesson.exercises, hasLength(9));
  final exerciseIds = <String>{};
  for (final ex in lesson.exercises) {
    expect(exerciseIds.add(ex.id), isTrue, reason: '题目 id 唯一：${ex.id}');
    expect(ex.answer, isNotEmpty);
    switch (ex.type) {
      case ExerciseType.translateChoice:
      case ExerciseType.listeningChoice:
        expect(ex.options, hasLength(4));
        expect(ex.options, contains(ex.answer), reason: '答案必须在选项中');
      case ExerciseType.wordBank:
        expect(ex.sentence, ex.answer);
      case ExerciseType.fillBlank:
        expect(ex.sentenceWithBlank, contains('____'));
      case ExerciseType.speaking:
        expect(ex.sentence, ex.answer);
        expect(ex.options, isEmpty);
    }
  }
}

void main() {
  test('初级课程 JSON 为 128 关且结构完整', () {
    final file = File('assets/courses/course_beginner.json');
    expect(file.existsSync(), isTrue);

    final course = Course.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );

    expect(course.id, 'beginner');
    expect(course.title, '英语初级');
    expect(course.units, hasLength(32));
    final lessons = course.orderedLessons;
    expect(lessons, hasLength(128));
    expect(lessons.map((l) => l.id).toSet(), hasLength(128));

    for (final lesson in lessons) {
      _assertExerciseShape(lesson);
    }
  });

  test('零基础课程 JSON 为 128 关且 id 不与初级冲突', () {
    final zero = Course.fromJson(
      jsonDecode(File('assets/courses/course_zero.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final beginner = Course.fromJson(
      jsonDecode(File('assets/courses/course_beginner.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    expect(zero.id, 'zero');
    expect(zero.title, '英语零基础');
    expect(zero.units, hasLength(32));
    expect(zero.orderedLessons, hasLength(128));
    expect(
      zero.orderedLessons.map((lesson) => lesson.id).toSet(),
      hasLength(128),
    );

    for (var unitIndex = 0; unitIndex < zero.units.length; unitIndex++) {
      final unit = zero.units[unitIndex];
      expect(unit.id, 'z_u${unitIndex + 1}');
      expect(unit.lessons, hasLength(4));
      for (
        var lessonIndex = 0;
        lessonIndex < unit.lessons.length;
        lessonIndex++
      ) {
        expect(unit.lessons[lessonIndex].id, '${unit.id}l${lessonIndex + 1}');
      }
    }

    for (final lesson in zero.orderedLessons) {
      _assertExerciseShape(lesson);
    }

    for (final lesson in zero.orderedLessons.skip(64)) {
      for (final exercise in lesson.exercises) {
        if (exercise.type == ExerciseType.translateChoice ||
            exercise.type == ExerciseType.listeningChoice) {
          expect(exercise.options.toSet(), hasLength(4), reason: exercise.id);
        }
        if (exercise.type == ExerciseType.fillBlank) {
          expect(
            exercise.sentenceWithBlank!.replaceFirst('____', exercise.answer),
            exercise.sentence,
            reason: exercise.id,
          );
        }
      }
    }

    final allLessonIds = [
      ...beginner.orderedLessons,
      ...zero.orderedLessons,
    ].map((l) => l.id).toList();
    expect(allLessonIds.toSet(), hasLength(allLessonIds.length));

    final allUnitIds = [
      ...beginner.units,
      ...zero.units,
    ].map((u) => u.id).toList();
    expect(allUnitIds.toSet(), hasLength(allUnitIds.length));
  });
}
