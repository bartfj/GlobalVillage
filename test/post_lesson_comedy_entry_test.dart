import 'dart:async';

import 'package:english_village/app/providers.dart';
import 'package:english_village/app/selected_track_controller.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/repositories/reward_repository.dart';
import 'package:english_village/features/lesson/result_page.dart';
import 'package:english_village/features/lesson/widgets/award_celebration.dart';
import 'package:english_village/features/post_lesson_comedy/post_lesson_comedy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_overrides.dart';

void _testComedyWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(
    name,
    body,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}

const _lesson = Lesson(id: 'u4l4', title: '点餐', exercises: []);
const _unit = Unit(id: 'u4', title: '食物', description: '', lessons: [_lesson]);
const _course = Course(id: 'beginner', title: '初级', units: [_unit]);

class _Progress implements ProgressRepository {
  final pending = Completer<bool>();
  int calls = 0;
  bool fail = false;
  @override
  Future<bool> recordResult({
    required String lessonId,
    required int correctCount,
    required int totalCount,
  }) {
    calls++;
    if (fail) throw StateError('disk failure');
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rewards implements RewardRepository {
  final pending = Completer<RewardAward?>();
  int calls = 0;
  @override
  Future<RewardAward?> awardForPassedAttempt(
    String lessonId,
    String attemptId,
  ) {
    calls++;
    return pending.future;
  }

  @override
  int get treeCount => 1;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Track extends StateNotifier<CourseTrack>
    implements SelectedTrackController {
  _Track(super.state);
  void change(CourseTrack track) => state = track;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _testAccount = StateProvider<ProgressRepository?>((ref) => null);

void main() {
  late _Progress progress;
  late _Rewards rewards;
  late _Track selected;
  setUp(() {
    progress = _Progress();
    rewards = _Rewards();
  });
  Widget app({CourseTrack track = CourseTrack.beginner, bool passed = true}) {
    selected = _Track(track);
    return ProviderScope(
      overrides: [
        uiStringsOverride,
        courseProvider.overrideWithValue(_course),
        _testAccount.overrideWith((ref) => progress),
        progressRepositoryProvider.overrideWith(
          (ref) => ref.watch(_testAccount),
        ),
        rewardRepositoryProvider.overrideWithValue(rewards),
        selectedTrackProvider.overrideWith((ref) => selected),
      ],
      child: MaterialApp(
        home: ResultPage(
          lessonId: _lesson.id,
          result: LessonResult(
            correctCount: passed ? 7 : 6,
            totalCount: 10,
            elapsedSeconds: 30,
            attemptId: 'attempt',
          ),
        ),
      ),
    );
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  Future<void> save(WidgetTester tester, {bool newlyAwarded = true}) async {
    progress.pending.complete(true);
    await flush(tester);
    rewards.pending.complete(
      RewardAward(
        lesson: _lesson,
        unit: _unit,
        count: 1,
        newlyAwarded: newlyAwarded,
      ),
    );
    await flush(tester);
    await tester.pump();
  }

  Future<void> remove(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  _testComedyWidgets('English comedy waits for both result and reward saves', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(PostLessonComedy), findsNothing);
    progress.pending.complete(true);
    await flush(tester);
    expect(find.byType(PostLessonComedy), findsNothing);
    expect(rewards.calls, 1);
    rewards.pending.complete(
      const RewardAward(
        lesson: _lesson,
        unit: _unit,
        count: 1,
        newlyAwarded: true,
      ),
    );
    await flush(tester);
    expect(find.byType(PostLessonComedy), findsOneWidget);
    expect(find.byType(AwardCelebration), findsNothing);
    final comedy = tester.widget<PostLessonComedy>(
      find.byType(PostLessonComedy),
    );
    expect(comedy.courseId, 'beginner');
    expect(comedy.lessonId, 'u4l4');
    comedy.onFinished();
    await tester.pump();
    expect(find.byType(AwardCelebration), findsOneWidget);
    expect(progress.calls, 1);
    expect(rewards.calls, 1);
    await remove(tester);
  });

  _testComedyWidgets(
    'repeat passes still show comedy and replay never awards again',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();
      await save(tester, newlyAwarded: false);
      tester
          .widget<PostLessonComedy>(find.byType(PostLessonComedy))
          .onFinished();
      await tester.pump();
      tester
          .widget<AwardCelebration>(find.byType(AwardCelebration))
          .onCollect();
      await tester.pump();
      final replay = find.byKey(const ValueKey('replay-comedy'));
      expect(replay, findsOneWidget);
      await tester.ensureVisible(replay);
      await tester.tap(replay);
      await tester.pump();
      expect(find.byType(PostLessonComedy), findsOneWidget);
      expect(progress.calls, 1);
      expect(rewards.calls, 1);
      await remove(tester);
    },
  );

  _testComedyWidgets('save failure never starts comedy', (tester) async {
    progress.fail = true;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(PostLessonComedy), findsNothing);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(rewards.calls, 0);
    await remove(tester);
  });

  for (final phase in ['progress', 'reward']) {
    _testComedyWidgets(
      'course switch during $phase save cannot reopen old comedy',
      (tester) async {
        await tester.pumpWidget(app());
        await tester.pump();
        if (phase == 'reward') {
          progress.pending.complete(true);
          await flush(tester);
        }
        selected.change(CourseTrack.zero);
        await tester.pump();
        if (phase == 'progress') progress.pending.complete(true);
        rewards.pending.complete(
          const RewardAward(
            lesson: _lesson,
            unit: _unit,
            count: 1,
            newlyAwarded: true,
          ),
        );
        await flush(tester);
        await tester.pump();
        expect(find.byType(PostLessonComedy), findsNothing);
        expect(find.byKey(const ValueKey('replay-comedy')), findsNothing);
        expect(rewards.calls, phase == 'reward' ? 1 : 0);
        await remove(tester);
      },
    );
  }
  _testComedyWidgets(
    'same-course account switch closes comedy and disables stale replay',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();
      await save(tester);
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(ResultPage)),
      );
      scope.read(_testAccount.notifier).state = _Progress();
      await tester.pump();
      expect(find.byType(PostLessonComedy), findsNothing);
      expect(find.byKey(const ValueKey('replay-comedy')), findsNothing);
      expect(rewards.calls, 1);
      await remove(tester);
    },
  );

  _testComedyWidgets('below 70 percent never starts comedy or awards', (
    tester,
  ) async {
    await tester.pumpWidget(app(passed: false));
    await tester.pump();
    progress.pending.complete(true);
    await tester.pump();
    expect(find.byType(PostLessonComedy), findsNothing);
    expect(rewards.calls, 0);
    await remove(tester);
  });

  for (final track in [CourseTrack.chinese, CourseTrack.sanskrit]) {
    _testComedyWidgets(
      '${track.id} retains celebration without English comedy',
      (tester) async {
        await tester.pumpWidget(app(track: track));
        await tester.pump();
        await save(tester);
        expect(find.byType(PostLessonComedy), findsNothing);
        expect(find.byType(AwardCelebration), findsOneWidget);
        await remove(tester);
      },
    );
  }
}
