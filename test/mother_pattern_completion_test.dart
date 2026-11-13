import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/repositories/reward_repository.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/data/sources/mother_pattern_store.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_completion.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_controller.dart';

class PatternProgress implements ProgressRepository {
  int saves = 0;
  bool fail = false;
  Completer<bool>? waiting;
  final completed = <String>{};
  @override
  bool isLessonUnlocked(String id) => true;
  @override
  bool isLessonCompleted(String id) => completed.contains(id);
  @override
  Future<bool> recordResult({
    required String lessonId,
    required int correctCount,
    required int totalCount,
  }) async {
    saves++;
    if (fail) throw StateError('disk full');
    if (waiting != null) return waiting!.future;
    final passed = correctCount / totalCount >= .7;
    if (passed) completed.add(lessonId);
    return passed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PatternRewards implements RewardRepository {
  PatternRewards(this.course);
  @override
  final Course course;
  final attempts = <String>{};
  bool fail = false;
  @override
  int get treeCount => attempts.length;
  @override
  Future<RewardAward?> awardForPassedAttempt(
    String lesson,
    String attempt,
  ) async {
    if (fail) throw StateError('reward disk full');
    return RewardAward(
      lesson: course.lessonById(lesson)!,
      unit: course.units.first,
      count: attempts.length + (attempts.contains(attempt) ? 0 : 1),
      newlyAwarded: attempts.add(attempt),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FailingPatternStore extends MotherPatternStore {
  FailingPatternStore({
    required super.userKey,
    required super.learningStore,
    super.clock,
  });
  bool fail = false;
  @override
  Future<MotherPatternSessionResult> recordSession({
    required String courseId,
    required Lesson lesson,
    required String sessionId,
    required MotherPatternState state,
    MotherPatternReviewSnapshot? reviewSnapshot,
  }) async {
    if (fail) throw StateError('session disk full');
    return super.recordSession(
      courseId: courseId,
      lesson: lesson,
      sessionId: sessionId,
      state: state,
      reviewSnapshot: reviewSnapshot,
    );
  }
}

MotherPatternState finishPattern(
  Lesson lesson, {
  MotherPatternReviewSnapshot? snapshot,
}) {
  final controller = MotherPatternController(
    lesson: lesson,
    reviewExercises: snapshot?.exercises,
  );
  while (!controller.state.finished) {
    final e = controller.state.current;
    controller.submit(
      e.answer,
      modality: e.type == ExerciseType.speaking
          ? MotherPatternModality.spoken
          : MotherPatternModality.typed,
    );
    controller.next();
  }
  return controller.state;
}

void main() {
  late Directory temp;
  late Course course;
  late Lesson lesson;
  late LearningStore learning;
  late FailingPatternStore store;
  late PatternProgress progress;
  late PatternRewards rewards;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mp-completion');
    Hive.init(temp.path);
    await Hive.openBox<String>(LearningStore.boxName);
    course = Course.fromJson(
      jsonDecode(
        File('assets/courses/course_mother_pattern.json').readAsStringSync(),
      ),
    );
    lesson = course.orderedLessons.first;
    learning = LearningStore(userKey: 'alice');
    store = FailingPatternStore(
      userKey: 'alice',
      learningStore: learning,
      clock: () => DateTime(2026, 11, 13),
    );
    progress = PatternProgress();
    rewards = PatternRewards(course);
  });
  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  MotherPatternCompletion session({
    bool practice = false,
    MotherPatternReviewSnapshot? snapshot,
  }) => MotherPatternCompletion(
    course: course,
    lesson: lesson,
    store: store,
    progress: progress,
    rewards: rewards,
    sessionId: 'attempt-1',
    practice: practice,
    reviewSnapshot: snapshot,
  );

  test(
    'main training saves scores rewards and independent record idempotently',
    () async {
      final s = session();
      final state = finishPattern(lesson);
      final first = await s.save(state, isCurrent: () => true);
      final second = await s.save(state, isCurrent: () => true);
      expect(first.record.reason, MotherPatternSaveReason.learning);
      expect(second.record.entry!.revision, first.record.entry!.revision);
      expect(rewards.treeCount, 1);
      expect(
        learning.events
            .where((e) => e['kind'] == 'motherPatternSession')
            .length,
        1,
      );
    },
  );
  test(
    'required session failure exposes retry without duplicating rewards',
    () async {
      store.fail = true;
      final s = session();
      final state = finishPattern(lesson);
      await expectLater(s.save(state, isCurrent: () => true), throwsStateError);
      expect(rewards.treeCount, 1);
      expect(store.latestSummary(course.id, lesson.patternLesson!), isNull);
      store.fail = false;
      await s.save(state, isCurrent: () => true);
      expect(rewards.treeCount, 1);
      expect(store.latestSummary(course.id, lesson.patternLesson!), isNotNull);
    },
  );
  test(
    'progress or reward failure prevents the expression record save',
    () async {
      progress.fail = true;
      final s = session();
      final state = finishPattern(lesson);
      await expectLater(s.save(state, isCurrent: () => true), throwsStateError);
      expect(rewards.treeCount, 0);
      progress.fail = false;
      rewards.fail = true;
      await expectLater(s.save(state, isCurrent: () => true), throwsStateError);
      expect(store.latestSummary(course.id, lesson.patternLesson!), isNull);
    },
  );
  test(
    'account interruption between awaited writes cannot save reward or session',
    () async {
      var current = true;
      progress.waiting = Completer<bool>();
      final saving = session().save(
        finishPattern(lesson),
        isCurrent: () => current,
      );
      current = false;
      progress.waiting!.complete(true);
      await expectLater(saving, throwsStateError);
      expect(rewards.treeCount, 0);
      expect(learning.events, isEmpty);
    },
  );
  test(
    'overlapping completion submissions share required writes and reward identity',
    () async {
      progress.waiting = Completer<bool>();
      final s = session();
      final state = finishPattern(lesson);
      final first = s.save(state, isCurrent: () => true);
      final second = s.save(state, isCurrent: () => true);
      progress.waiting!.complete(true);
      await Future.wait([first, second]);
      expect(progress.saves, 1);
      expect(rewards.treeCount, 1);
      expect(
        learning.events
            .where((e) => e['kind'] == 'motherPatternSession')
            .length,
        1,
      );
    },
  );
  test(
    'below seventy percent saves evidence without ordinary completion reward',
    () async {
      final controller = MotherPatternController(lesson: lesson);
      for (var i = 0; i < 10; i++) {
        final e = controller.state.current;
        controller.submit(
          i < 6 ? e.answer : 'wrong',
          modality: e.type == ExerciseType.speaking
              ? MotherPatternModality.spoken
              : MotherPatternModality.typed,
        );
        controller.next();
      }
      while (!controller.state.finished) {
        final e = controller.state.current;
        controller.submit(
          e.answer,
          modality: e.type == ExerciseType.speaking
              ? MotherPatternModality.spoken
              : MotherPatternModality.typed,
        );
        controller.next();
      }
      final saved = await session().save(
        controller.state,
        isCurrent: () => true,
      );
      expect(saved.award, isNull);
      expect(rewards.treeCount, 0);
      expect(progress.completed, isEmpty);
      expect(
        store.latestSummary(course.id, lesson.patternLesson!)!.firstCorrect,
        6,
      );
    },
  );
  test(
    'review and full refresher preserve ordinary scores and rewards',
    () async {
      await session(
        practice: true,
      ).save(finishPattern(lesson), isCurrent: () => true);
      expect(progress.saves, 0);
      expect(rewards.treeCount, 0);
      final snapshot = store.reviewSnapshot(course.id, lesson);
      final result = await MotherPatternCompletion(
        course: course,
        lesson: lesson,
        store: store,
        progress: progress,
        rewards: rewards,
        sessionId: 'review',
        reviewSnapshot: snapshot,
      ).save(finishPattern(lesson, snapshot: snapshot), isCurrent: () => true);
      expect(result.record.reason, MotherPatternSaveReason.practice);
      expect(result.record.scheduleAdvanced, false);
      expect(progress.saves, 0);
      expect(rewards.treeCount, 0);
    },
  );
}
