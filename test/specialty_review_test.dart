import 'dart:convert';
import 'dart:io';

import 'package:english_village/app/providers.dart';
import 'package:english_village/app/selected_track_controller.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/data/models/skill_practice.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/sources/content_documents.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/data/sources/skill_practice_loader.dart';
import 'package:english_village/features/learning_path/review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'ui_test_overrides.dart';

class _SanskritTrack extends StateNotifier<CourseTrack>
    implements SelectedTrackController {
  _SanskritTrack() : super(CourseTrack.sanskrit);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a legacy shared-ID practice mistake stays in its own course', () async {
    final temp = await Directory.systemTemp.createTemp('shared_review');
    Hive.init(temp.path);
    addTearDown(() async {
      await Hive.close();
      await temp.delete(recursive: true);
    });
    final box = await Hive.openBox<String>(LearningStore.boxName);
    var now = DateTime.utc(2026, 11, 22);
    final store = LearningStore(userKey: 'learner', clock: () => now);
    const question = Exercise(
      id: 'u2l1e6',
      type: ExerciseType.listeningChoice,
      prompt: 'Listen',
      sentence: 'Hello.',
      options: ['Hello.', 'Goodbye.'],
      answer: 'Hello.',
    );
    const lessons = [
      Unit(
        id: 'u2',
        title: 'Second unit',
        description: '',
        lessons: [
          Lesson(id: 'u2l1', title: 'Lesson', exercises: [question]),
        ],
      ),
    ];
    const beginner = Course(id: 'beginner', title: 'Beginner', units: lessons);
    const other = Course(
      id: 'intermediate',
      title: 'Intermediate',
      units: lessons,
    );
    await box.put(
      'learner|reviews',
      jsonEncode({
        question.id: {
          'courseId': beginner.id,
          'lessonId': 'u2l1',
          'stage': 0,
          'due': now.toIso8601String(),
          'resolved': false,
        },
      }),
    );
    await store.log({
      'kind': 'answer',
      'courseId': beginner.id,
      'lessonId': 'u2l1',
      'exerciseId': question.id,
      'correct': false,
      'mode': 'skill-pronunciation/pr-early',
    });

    expect(store.hasDuePracticeReviews(beginner.id), isTrue);
    expect(store.dueExercises(beginner, {}, practiceExercises: [question]), [
      question,
    ]);
    expect(
      store.dueExercises(other, {'u2l1'}, practiceExercises: [question]),
      isEmpty,
    );

    await store.recordAnswer(
      courseId: beginner.id,
      lessonId: 'u2l1',
      exercise: question,
      correct: true,
      first: true,
      elapsedMs: 1000,
      mode: 'review',
    );
    expect(
      store.dueExercises(beginner, {}, practiceExercises: [question]),
      isEmpty,
    );
    await box.delete('learner|events');
    now = now.add(const Duration(days: 1));
    expect(store.dueExercises(beginner, {}, practiceExercises: [question]), [
      question,
    ]);
    expect(
      store.dueExercises(other, {'u2l1'}, practiceExercises: [question]),
      isEmpty,
    );
  });

  testWidgets(
    'existing Yoga Sanskrit records and wrong answers appear in review',
    (tester) async {
      final now = DateTime.utc(2026, 11, 22);
      final store = LearningStore(userKey: 'learner', clock: () => now);
      const course = Course(
        id: 'sanskrit',
        title: '梵文入门',
        units: [],
        language: LearningLanguage.sanskrit,
      );
      const skill = SkillPracticeKind.sanskritYoga;

      await tester.runAsync(() async {
        final temp = await Directory.systemTemp.createTemp('specialty_review');
        Hive.init(temp.path);
        addTearDown(() async {
          await Hive.close();
          await temp.delete(recursive: true);
        });
        await Hive.openBox<String>(LearningStore.boxName);
        final bank = await SkillPracticeLoader().load(skill);
        final chapter = bank.chapters.first;
        final mode = skill.modeForChapter(chapter.id);
        final lessonId = 'practice-${skill.name}-${chapter.id}';
        await store.log({
          'kind': 'start',
          'courseId': course.id,
          'lessonId': lessonId,
          'mode': mode,
        });
        await store.recordAnswer(
          courseId: course.id,
          lessonId: lessonId,
          exercise: chapter.exercises.first,
          correct: false,
          first: true,
          elapsedMs: 1000,
          mode: mode,
        );
        await store.log({
          'kind': 'finish',
          'courseId': course.id,
          'lessonId': lessonId,
          'mode': mode,
        });
        final alreadyReviewed = chapter.exercises[2];
        await store.recordAnswer(
          courseId: course.id,
          lessonId: lessonId,
          exercise: alreadyReviewed,
          correct: false,
          first: true,
          elapsedMs: 1000,
          mode: mode,
        );
        await store.recordAnswer(
          courseId: course.id,
          lessonId: 'practice',
          exercise: alreadyReviewed,
          correct: true,
          first: true,
          elapsedMs: 1000,
          mode: 'review',
        );
        expect(store.reviews[alreadyReviewed.id]['stage'], 1);
        expect(store.reviews[alreadyReviewed.id]['lessonId'], lessonId);
        await store.recordAnswer(
          courseId: 'sanskritZero',
          lessonId: lessonId,
          exercise: chapter.exercises[1],
          correct: false,
          first: true,
          elapsedMs: 1000,
          mode: mode,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uiStringsOverride,
            selectedTrackProvider.overrideWith((ref) => _SanskritTrack()),
            courseProvider.overrideWithValue(course),
            learningStoreProvider.overrideWithValue(store),
            contentCacheProvider.overrideWith(
              (ref) async => const EmptyContentDocuments(),
            ),
            progressRepositoryProvider.overrideWithValue(
              ProgressRepository(
                course: course,
                store: const ProgressStore(userKey: 'learner'),
              ),
            ),
          ],
          child: const MaterialApp(home: ReviewPage()),
        ),
      );
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });
      await tester.pumpAndSettle();

      expect(find.text('1 题待复习'), findsOneWidget);
      final wrongAnswers = tester.widget<ListTile>(
        find.ancestor(of: find.text('今日错题'), matching: find.byType(ListTile)),
      );
      expect(wrongAnswers.onTap, isNotNull);
      final records = find.ancestor(
        of: find.text('瑜伽梵文'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: records, matching: find.textContaining('完成 1 次')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    },
  );
}
