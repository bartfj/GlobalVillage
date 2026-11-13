import 'dart:convert';
import 'dart:io';

import 'package:english_village/app/providers.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/repositories/course_repository.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/features/lesson/lesson_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_overrides.dart';

class _CompletedProgress implements ProgressStore {
  @override
  LessonProgress? get(String id) => LessonProgress(
    lessonId: id,
    completed: true,
    score: 100,
    correctCount: 9,
    totalCount: 9,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('debug lesson entry skips the pilot study card', (tester) async {
    final course = Course.fromJson(
      jsonDecode(File('assets/courses/course_beginner.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    for (final page in const [
      LessonPage(lessonId: 'u1l2', bypassUnlock: true),
      LessonPage(lessonId: 'u1l2', initialExerciseIndex: 1),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            uiStringsOverride,
            courseProvider.overrideWithValue(course),
            courseRepositoryProvider.overrideWithValue(
              CourseRepository(course),
            ),
            progressRepositoryProvider.overrideWithValue(
              ProgressRepository(store: _CompletedProgress(), course: course),
            ),
            learningStoreProvider.overrideWithValue(null),
          ],
          child: MaterialApp(home: page),
        ),
      );
      expect(find.text('My name is …'), findsNothing);
      expect(find.text('检查'), findsOneWidget);
    }
  });
  testWidgets(
    'ordinary lesson ignores cached pilot metadata and starts scored questions',
    (tester) async {
      final course = Course.fromJson(
        jsonDecode(
              File('assets/courses/course_beginner.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uiStringsOverride,
            courseProvider.overrideWithValue(course),
            courseRepositoryProvider.overrideWithValue(
              CourseRepository(course),
            ),
            progressRepositoryProvider.overrideWithValue(
              ProgressRepository(store: _CompletedProgress(), course: course),
            ),
            learningStoreProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(home: LessonPage(lessonId: 'u1l2')),
        ),
      );
      expect(find.text('My name is …'), findsNothing);
      expect(find.text('认识本课母句型'), findsNothing);
      expect(find.text('检查'), findsOneWidget);
      expect(course.lessonById('u1l2')!.exercises.length, 9);
    },
  );
}
