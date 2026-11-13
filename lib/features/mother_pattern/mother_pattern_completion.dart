import '../../data/models/course.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/sources/mother_pattern_store.dart';
import 'mother_pattern_controller.dart';
import '../../core/constants.dart';

class MotherPatternCompletionResult {
  const MotherPatternCompletionResult(this.record, this.award, this.treeCount);
  final MotherPatternSessionResult record;
  final RewardAward? award;
  final int treeCount;
}

class MotherPatternCompletion {
  MotherPatternCompletion({
    required this.course,
    required this.lesson,
    required this.store,
    required this.progress,
    required this.rewards,
    required this.sessionId,
    this.reviewSnapshot,
    this.practice = false,
  });
  final Course course;
  final Lesson lesson;
  final MotherPatternStore store;
  final ProgressRepository? progress;
  final RewardRepository? rewards;
  final String sessionId;
  final MotherPatternReviewSnapshot? reviewSnapshot;
  final bool practice;
  Future<MotherPatternCompletionResult>? _pending;
  MotherPatternCompletionResult? _saved;
  bool _progressSaved = false;
  RewardAward? _award;
  Future<MotherPatternCompletionResult> save(
    MotherPatternState state, {
    required bool Function() isCurrent,
  }) async {
    _check(isCurrent);
    if (!state.finished) throw StateError('Complete the session before saving');
    if (_saved != null) return _saved!;
    if (_pending != null) return _pending!;
    final pending = _save(state, isCurrent);
    _pending = pending;
    try {
      return await pending;
    } finally {
      _pending = null;
    }
  }

  void _check(bool Function() isCurrent) {
    if (!isCurrent()) throw StateError('The session account or course changed');
  }

  Future<MotherPatternCompletionResult> _save(
    MotherPatternState state,
    bool Function() isCurrent,
  ) async {
    final mainLesson = !practice && reviewSnapshot == null;
    if (mainLesson) {
      if (progress == null || rewards == null) {
        throw StateError('No active learning repositories');
      }
      if (!_progressSaved) {
        await progress!.recordResult(
          lessonId: lesson.id,
          correctCount: state.firstCorrectCount,
          totalCount: state.totalCount,
        );
        _progressSaved = true;
      }
      _check(isCurrent);
      if (state.accuracy >= kPassThreshold && _award == null) {
        _award = await rewards!.awardForPassedAttempt(lesson.id, sessionId);
        if (_award == null) throw StateError('Reward save failed');
      }
      _check(isCurrent);
    }
    final record = await store.recordSession(
      courseId: course.id,
      lesson: lesson,
      sessionId: sessionId,
      state: state,
      reviewSnapshot: reviewSnapshot,
    );
    _check(isCurrent);
    return _saved = MotherPatternCompletionResult(
      record,
      _award,
      _award == null ? 0 : rewards!.treeCount,
    );
  }
}
