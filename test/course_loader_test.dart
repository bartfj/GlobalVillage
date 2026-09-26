import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('内置课程 JSON 可解析且结构完整', () {
    final file = File('assets/courses/course_beginner.json');
    expect(file.existsSync(), isTrue, reason: '课程 JSON 文件必须存在');

    final course =
        Course.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);

    expect(course.units, hasLength(14));
    final lessons = course.orderedLessons;
    expect(lessons, hasLength(56));
    expect(lessons.map((l) => l.id).toSet(), hasLength(56), reason: '课程 id 唯一');

    final exerciseIds = <String>{};
    for (final lesson in lessons) {
      expect(lesson.exercises, hasLength(9));
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
    expect(exerciseIds, hasLength(504));
  });
}
