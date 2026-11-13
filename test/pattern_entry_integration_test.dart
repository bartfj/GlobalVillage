import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:english_village/app/providers.dart';
import 'package:english_village/app/selected_track_controller.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/repositories/reward_repository.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/features/learning_path/review_page.dart';
import 'package:english_village/features/lesson/result_page.dart';
import 'package:english_village/features/lesson/widgets/award_celebration.dart';
import 'package:english_village/features/pattern_training/pattern_training_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'ui_test_overrides.dart';

class _Progress implements ProgressRepository {
  final saved = Completer<bool>();
  bool fail = false;
  @override
  Future<bool> recordResult({
    required String lessonId,
    required int correctCount,
    required int totalCount,
  }) {
    if (fail) throw StateError('disk failure');
    return saved.future;
  }

  @override
  bool isLessonCompleted(String id) => id == 'u1l2';
  @override
  bool isLessonUnlocked(String id) => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rewards implements RewardRepository {
  final saved = Completer<RewardAward?>();
  @override
  Future<RewardAward?> awardForPassedAttempt(String lesson, String attempt) =>
      saved.future;
  @override
  int get treeCount => 1;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Track extends StateNotifier<CourseTrack>
    implements SelectedTrackController {
  _Track() : super(CourseTrack.chinese);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;
  late Course course;
  late LearningStore store;
  late _Progress progress;
  late _Rewards rewards;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pattern-entry');
    Hive.init(temp.path);
    await Hive.openBox<String>(LearningStore.boxName);
    course = Course.fromJson(
      jsonDecode(File('assets/courses/course_beginner.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    store = LearningStore(userKey: 'old-user');
    progress = _Progress();
    rewards = _Rewards();
  });
  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  Widget app(Widget page) => ProviderScope(
    overrides: [
      uiStringsOverride,
      courseProvider.overrideWithValue(course),
      learningStoreProvider.overrideWithValue(store),
      progressRepositoryProvider.overrideWithValue(progress),
      rewardRepositoryProvider.overrideWithValue(rewards),
      selectedTrackProvider.overrideWith((ref) => _Track()),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: page,
    ),
  );

  testWidgets(
    'post-lesson practice appears only after progress and rewards save',
    (tester) async {
      await tester.pumpWidget(
        app(
          const ResultPage(
            lessonId: 'u1l2',
            result: LessonResult(
              correctCount: 7,
              totalCount: 9,
              elapsedSeconds: 40,
              attemptId: 'passed',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('练习本课母句型'), findsNothing);
      await tester.runAsync(() async {
        progress.saved.complete(true);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(find.text('练习本课母句型'), findsNothing);
      await tester.runAsync(() async {
        rewards.saved.complete(
          RewardAward(
            lesson: course.lessonById('u1l2')!,
            unit: course.units.first,
            count: 1,
            newlyAwarded: true,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      await tester.pump();
      tester
          .widget<AwardCelebration>(find.byType(AwardCelebration))
          .onCollect();
      await tester.pump();
      await tester.scrollUntilVisible(find.text('练习本课母句型'), 200);
      await tester.tap(find.text('练习本课母句型'));
      await tester.pumpAndSettle();
      expect(find.byType(PatternTrainingPage), findsOneWidget);
      expect(store.patternReviews, isEmpty);
    },
  );
  testWidgets('failed save keeps optional practice hidden', (tester) async {
    progress.fail = true;
    await tester.pumpWidget(
      app(
        const ResultPage(
          lessonId: 'u1l2',
          result: LessonResult(
            correctCount: 7,
            totalCount: 9,
            elapsedSeconds: 40,
            attemptId: 'failed-save',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('练习本课母句型'), findsNothing);
    expect(store.patternReviews, isEmpty);
  });
  testWidgets(
    'old completed lesson is available without inventing trained mastery',
    (tester) async {
      await tester.pumpWidget(app(const ReviewPage()));
      expect(find.text('今日母句型'), findsOneWidget);
      expect(find.text('暂无到期母句型'), findsOneWidget);
      expect(find.text('尚未练习'), findsOneWidget);
      final title = '${course.lessonById('u1l2')!.title} · My name is …';
      await tester.scrollUntilVisible(find.text(title), 150);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(PatternTrainingPage), findsOneWidget);
      expect(store.patternReviews, isEmpty);
    },
  );
}
