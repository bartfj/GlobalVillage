import 'dart:convert';
import 'dart:io';

import 'package:english_village/app/providers.dart';
import 'package:english_village/core/services/tts_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/features/pattern_training/pattern_training_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'ui_test_overrides.dart';

class _Voice implements TtsService {
  final List<String> played = [];
  @override
  Future<bool> speakExercise(Exercise exercise) async {
    played.add(exercise.id);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;
  late Course course;
  late LearningStore store;
  final now = DateTime(2026, 11, 12, 10);
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pattern-page');
    Hive.init(temp.path);
    await Hive.openBox<String>(LearningStore.boxName);
    course = Course.fromJson(
      jsonDecode(File('assets/courses/course_beginner.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    store = LearningStore(userKey: 'alice', clock: () => now);
  });
  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester, {bool finishing = false}) async {
    await tester.ensureVisible(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final before = store.events.length;
      await tester.tap(find.text('继续'));
      // Hive file writes run on the real event loop, outside the fake widget clock.
      if (finishing) {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (store.events.length == before &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(store.events.length, greaterThan(before));
        await Future<void>.delayed(Duration.zero);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> answer(
    WidgetTester tester,
    Exercise exercise, {
    bool finishing = false,
  }) async {
    if (exercise.type == ExerciseType.wordBank) {
      for (final token in exercise.tokens) {
        await tap(tester, token);
      }
    } else {
      expect(find.text(exercise.answer), findsNothing);
      expect(find.text('My name is …'), findsNothing);
      await tester.enterText(find.byType(TextFormField), exercise.answer);
    }
    await tap(tester, '检查');
    await next(tester, finishing: finishing);
  }

  Widget app(Lesson lesson, _Voice voice, {bool review = false}) =>
      ProviderScope(
        overrides: [
          uiStringsOverride,
          courseProvider.overrideWithValue(course),
          learningStoreProvider.overrideWithValue(store),
          ttsServiceProvider.overrideWithValue(voice),
        ],
        child: MaterialApp(
          home: PatternTrainingPage(lesson: lesson, review: review),
        ),
      );

  testWidgets(
    'six questions save an independent schedule without leaking input answers',
    (tester) async {
      final lesson = course.lessonById('u1l2')!;
      final voice = _Voice();
      await tester.pumpWidget(app(lesson, voice));
      for (final e in lesson.patternTraining!.exercises) {
        await answer(
          tester,
          e,
          finishing: e.id == lesson.patternTraining!.exercises.last.id,
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('本次训练已记录'), findsOneWidget);
      expect(find.text('首次答对 6 / 6'), findsOneWidget);
      expect(voice.played, isEmpty);
      expect(
        store
            .patternReview(course.id, lesson.patternTraining!)!
            .due
            .isAtSameMomentAs(now.add(const Duration(days: 1))),
        isTrue,
      );
      expect(store.reviews, isEmpty);
      expect(
        store.events.where((e) => e['kind'] == 'patternSession').length,
        1,
      );
    },
  );

  testWidgets(
    'review hints prevent advancement and layout works on small large-text screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final lesson = course.lessonById('u1l2')!;
      final training = lesson.patternTraining!;
      await tester.runAsync(
        () => store.recordPatternSession(
          courseId: course.id,
          lessonId: lesson.id,
          sessionId: 'learn',
          training: training,
          review: false,
          independentSuccess: true,
          firstCorrect: 6,
          totalCount: 6,
          hints: 0,
        ),
      );
      final voice = _Voice();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uiStringsOverride,
            courseProvider.overrideWithValue(course),
            learningStoreProvider.overrideWithValue(store),
            ttsServiceProvider.overrideWithValue(voice),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.8)),
              child: child!,
            ),
            home: PatternTrainingPage(lesson: lesson, review: true),
          ),
        ),
      );
      expect(find.text(training.frame), findsNothing);
      await tap(tester, '看句型和范句');
      expect(find.text(training.frame), findsOneWidget);
      final exercises = store.patternReviewExercises(course.id, training);
      for (var i = 0; i < exercises.length; i++) {
        await tester.enterText(find.byType(TextFormField), exercises[i].answer);
        await tap(tester, '检查');
        await next(tester, finishing: i == exercises.length - 1);
      }
      await tester.pumpAndSettle();
      final entry = store.patternReview(course.id, training)!;
      expect(entry.due.isAtSameMomentAs(now), isTrue);
      expect(entry.stage, 0);
      expect(entry.hints, 1);
      expect(entry.reviewCursor, 2);
      expect(voice.played, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching accounts disables the old in-progress practice', (
    tester,
  ) async {
    final selected = StateProvider<LearningStore>((ref) => store);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uiStringsOverride,
          courseProvider.overrideWithValue(course),
          learningStoreProvider.overrideWith((ref) => ref.watch(selected)),
        ],
        child: MaterialApp(
          home: PatternTrainingPage(lesson: course.lessonById('u1l2')!),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PatternTrainingPage)),
    );
    container.read(selected.notifier).state = LearningStore(userKey: 'bob');
    await tester.pump();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('当前账号或课程无法继续这次练习。'), findsOneWidget);
    expect(store.patternReviews, isEmpty);
  });
}
