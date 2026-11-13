import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:english_village/app/app_strings.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/pattern_lesson.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/data/sources/mother_pattern_store.dart';
import 'package:english_village/features/learning_path/review_page.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_page.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_providers.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_speech.dart';
import 'mother_pattern_completion_test.dart'
    show PatternProgress, PatternRewards, finishPattern;
import 'mother_pattern_page_test.dart' show PatternVoice, PatternTrack;
import 'mother_pattern_speech_test.dart'
    show FakePatternRecorder, FakePatternRecognizer;
import 'ui_test_overrides.dart';

void main() {
  late Directory temp;
  late Course course;
  late LearningStore learning;
  late MotherPatternStore store;
  late PatternProgress progress;
  late PatternRewards rewards;
  late DateTime now;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mp-review-ui');
    Hive.init(temp.path);
    await Hive.openBox<String>(LearningStore.boxName);
    course = Course.fromJson(
      jsonDecode(
        File('assets/courses/course_mother_pattern.json').readAsStringSync(),
      ),
    );
    learning = LearningStore(userKey: 'alice');
    now = DateTime(2026, 11, 13);
    store = MotherPatternStore(
      userKey: 'alice',
      learningStore: learning,
      clock: () => now,
    );
    progress = PatternProgress();
    rewards = PatternRewards(course);
  });
  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  Future<void> app(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uiStringsOverride,
          courseProvider.overrideWithValue(course),
          learningStoreProvider.overrideWithValue(learning),
          motherPatternStoreProvider.overrideWithValue(store),
          progressRepositoryProvider.overrideWithValue(progress),
          rewardRepositoryProvider.overrideWithValue(rewards),
          ttsServiceProvider.overrideWithValue(PatternVoice()),
          selectedTrackProvider.overrideWith((ref) => PatternTrack()),
          motherPatternSpeechFactoryProvider.overrideWithValue(
            () => MotherPatternSpeech(
              recorder: FakePatternRecorder(),
              recognizer: FakePatternRecognizer(),
            ),
          ),
        ],
        child: const MaterialApp(home: ReviewPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('course menu label is bilingual', () {
    expect(
      const S(UiLanguage.chinese).trackLabel(CourseTrack.motherPattern),
      '母句型英语',
    );
    expect(
      const S(UiLanguage.english).trackLabel(CourseTrack.motherPattern),
      'Mother Pattern English',
    );
  });
  testWidgets(
    'completed lesson without new training has honest absent-record label and no due review',
    (tester) async {
      progress.completed.add(course.orderedLessons.first.id);
      await app(tester);
      expect(find.text('课程已完成 · 暂无表达训练记录'), findsOneWidget);
      expect(find.text('暂无到期母句型'), findsOneWidget);
      expect(
        find.byKey(ValueKey('review-due-${course.orderedLessons.first.id}')),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(ValueKey('refresher-${course.orderedLessons.first.id}')),
      );
      await tester.tap(
        find.byKey(ValueKey('refresher-${course.orderedLessons.first.id}')),
      );
      await tester.pumpAndSettle();
      final page = tester.widget<MotherPatternPage>(
        find.byType(MotherPatternPage),
      );
      expect(page.practice, true);
      expect(page.reviewSnapshot, isNull);
      expect(rewards.treeCount, 0);
    },
  );
  testWidgets(
    'due list uses new training records max six and keeps the opening snapshot',
    (tester) async {
      final lessons = course.orderedLessons
          .where((l) => l.patternLesson!.kind == PatternLessonKind.pattern)
          .take(8);
      await tester.runAsync(() async {
        for (final lesson in lessons) {
          await store.recordSession(
            courseId: course.id,
            lesson: lesson,
            sessionId: lesson.id,
            state: finishPattern(lesson),
          );
        }
      });
      now = DateTime(2026, 11, 14);
      await app(tester);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('review-due-'),
        ),
        findsNWidgets(6),
      );
      final first = lessons.first;
      final expected = store.reviewSnapshot(course.id, first);
      await tester.tap(find.byKey(ValueKey('review-due-${first.id}')));
      await tester.pumpAndSettle();
      final page = tester.widget<MotherPatternPage>(
        find.byType(MotherPatternPage),
      );
      expect(page.reviewSnapshot!.revisionToken, expected.revisionToken);
      expect(
        page.reviewSnapshot!.exercises.map((e) => e.id),
        expected.exercises.map((e) => e.id),
      );
      expect(find.text(first.title), findsNothing);
      expect(find.text(first.patternLesson!.frame), findsNothing);
    },
  );
  testWidgets(
    'restart summaries label extra practice separately and retain independent modalities',
    (tester) async {
      final lesson = course.orderedLessons.first;
      await tester.runAsync(() async {
        await store.recordSession(
          courseId: course.id,
          lesson: lesson,
          sessionId: 'learn',
          state: finishPattern(lesson),
        );
        final snapshot = store.reviewSnapshot(course.id, lesson);
        await store.recordSession(
          courseId: course.id,
          lesson: lesson,
          sessionId: 'practice',
          state: finishPattern(lesson, snapshot: snapshot),
          reviewSnapshot: snapshot,
        );
      });
      store = MotherPatternStore(
        userKey: 'alice',
        learningStore: learning,
        clock: () => now,
      );
      await app(tester);
      expect(find.textContaining('最近一次：额外练习'), findsOneWidget);
      expect(find.textContaining('独立首答 2 / 2'), findsOneWidget);
      expect(find.textContaining('口语首答 2'), findsOneWidget);
      expect(find.textContaining('键盘替代首答 0'), findsOneWidget);
    },
  );
}
