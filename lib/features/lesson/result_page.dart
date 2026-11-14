import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/adaptive/adaptive_content_column.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/services/diagnostic_log.dart';
import '../../data/models/lesson_badge.dart';
import '../../data/models/learning_language.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/reward_repository.dart';
import 'widgets/award_celebration.dart';
import '../post_lesson_comedy/post_lesson_comedy.dart';

/// 课程结算数据（由答题页通过路由 extra 传入）
class LessonResult {
  final int correctCount;
  final int totalCount;
  final int elapsedSeconds;
  final String attemptId;

  const LessonResult({
    required this.correctCount,
    required this.totalCount,
    required this.elapsedSeconds,
    required this.attemptId,
  });

  double get accuracy => totalCount == 0 ? 0 : correctCount / totalCount;
  bool get passed => accuracy >= kPassThreshold;

  /// 百分制得分：与正确率一致，全对即满分 100
  int get score => (accuracy * 100).round();
}

/// 课程结算页
class ResultPage extends ConsumerStatefulWidget {
  final String lessonId;
  final LessonResult result;

  const ResultPage({super.key, required this.lessonId, required this.result});

  @override
  ConsumerState<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends ConsumerState<ResultPage> {
  bool _saving = false;
  bool _saved = false;
  RewardAward? _award;
  int _treeCount = 0;
  String? _saveError;
  bool _showCelebration = false;
  bool _showDialogue = false;
  bool _celebrateAfterComedy = false;
  late final String _courseId;
  late final String _trackId;
  late final ProgressRepository? _progress;
  late final RewardRepository? _rewards;
  bool _sessionStopped = false;

  bool get _sessionCurrent =>
      mounted &&
      !_sessionStopped &&
      ref.read(selectedTrackProvider).id == _trackId &&
      ref.read(courseProvider).id == _courseId &&
      identical(ref.read(progressRepositoryProvider), _progress) &&
      identical(ref.read(rewardRepositoryProvider), _rewards);

  void _stopSession() {
    if (!mounted || _sessionStopped) return;
    setState(() {
      _sessionStopped = true;
      _showDialogue = false;
      _showCelebration = false;
      _celebrateAfterComedy = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _courseId = ref.read(courseProvider).id;
    _trackId = ref.read(selectedTrackProvider).id;
    _progress = ref.read(progressRepositoryProvider);
    _rewards = ref.read(rewardRepositoryProvider);
    // 回写学习结果并驱动学习路径刷新
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveResult());
    final log = DiagnosticLog.instance;
    if (log == null) return;
    final place =
        ref.read(courseProvider).lessonPlace(widget.lessonId) ??
        widget.lessonId;
    unawaited(
      log.rememberLesson(
        route: '/lesson/${widget.lessonId}/result',
        lesson: place,
      ),
    );
  }

  Future<void> _saveResult() async {
    if (_saving || _saved || _sessionStopped) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final progressRepo = _progress;
      final rewardRepo = _rewards;
      if (progressRepo == null || rewardRepo == null) {
        throw StateError('无有效会话，无法保存进度');
      }
      await progressRepo.recordResult(
        lessonId: widget.lessonId,
        correctCount: widget.result.correctCount,
        totalCount: widget.result.totalCount,
      );
      if (!_sessionCurrent) {
        _stopSession();
        return;
      }
      ref.read(progressRevisionProvider.notifier).state++;
      if (widget.result.passed) {
        final award = await rewardRepo.awardForPassedAttempt(
          widget.lessonId,
          widget.result.attemptId,
        );
        if (award == null) throw StateError('无法保存徽章奖励');
        if (!_sessionCurrent) {
          _stopSession();
          return;
        }
        ref.read(rewardRevisionProvider.notifier).state++;
        setState(() {
          _award = award;
          _treeCount = rewardRepo.treeCount;
          // 保存后观看独立短剧；播放和重播均不再次写入学习或奖励。
          _showDialogue =
              ref.read(selectedTrackProvider).language ==
              LearningLanguage.english;
          _showCelebration = !_showDialogue;
          _celebrateAfterComedy = _showDialogue;
        });
      }
      _saved = true;
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = ref.read(stringsProvider).saveFailed);
      }
    } finally {
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedTrackProvider, (_, track) {
      if (track.id != _trackId) _stopSession();
    });
    ref.listen(courseProvider, (_, course) {
      if (course.id != _courseId) _stopSession();
    });
    ref.listen(progressRepositoryProvider, (_, progress) {
      if (!identical(progress, _progress)) _stopSession();
    });
    ref.listen(rewardRepositoryProvider, (_, rewards) {
      if (!identical(rewards, _rewards)) _stopSession();
    });
    final s = ref.watch(stringsProvider);
    final result = widget.result;
    final passed = result.passed;
    final minutes = result.elapsedSeconds ~/ 60;
    final seconds = result.elapsedSeconds % 60;

    return PopScope(
      canPop: false,
      child: AdaptiveContentColumn(
        child: Scaffold(
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    children: [
                      const SizedBox(height: 24),
                      Icon(
                        passed
                            ? Icons.emoji_events_rounded
                            : Icons.refresh_rounded,
                        size: 96,
                        color: passed ? AppColors.gold : AppColors.blue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        passed ? s.lessonPassed : s.lessonFailed,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        passed ? s.nextUnlocked : s.passThresholdHint,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          _StatCard(
                            label: s.scoreLabel,
                            value: '${result.score}',
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            label: s.accuracyLabel,
                            value: '${(result.accuracy * 100).round()}%',
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            label: s.timeLabel,
                            value: s.minutesSeconds(minutes, seconds),
                            color: AppColors.blue,
                          ),
                        ],
                      ),
                      if (_award != null) ...[
                        const SizedBox(height: 18),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.85, end: 1),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 400),
                          builder: (context, value, child) =>
                              Transform.scale(scale: value, child: child),
                          child: Column(
                            children: [
                              Icon(
                                LessonBadgeStyle.forLesson(
                                  _award!.lesson.id,
                                ).icon,
                                size: 48,
                                color: LessonBadgeStyle.forLesson(
                                  _award!.lesson.id,
                                ).color,
                              ),
                              Text(
                                s.badgeEarned(
                                  _award!.lesson.title,
                                  _award!.newlyAwarded,
                                ),
                              ),
                              Text(s.badgeTotal(_award!.count)),
                              if (_treeCount > 0)
                                Text(s.treePlusOne(_treeCount)),
                            ],
                          ),
                        ),
                        if (_saved &&
                            !_sessionStopped &&
                            ref.watch(selectedTrackProvider).language ==
                                LearningLanguage.english)
                          TextButton.icon(
                            key: const ValueKey('replay-comedy'),
                            onPressed: () {
                              if (!_sessionCurrent) return;
                              setState(() {
                                _celebrateAfterComedy = false;
                                _showDialogue = true;
                              });
                            },
                            icon: const Icon(Icons.replay_rounded),
                            label: Text(s.comedyReplay),
                          ),
                      ],
                      if (_saveError != null) ...[
                        Text(
                          _saveError!,
                          style: const TextStyle(color: AppColors.red),
                        ),
                        TextButton(
                          onPressed: _saveResult,
                          child: Text(s.retrySave),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (!passed) ...[
                        PushableButton(
                          label: s.relearn,
                          onPressed: () =>
                              context.replace('/lesson/${widget.lessonId}'),
                          color: AppColors.blue,
                          shadowColor: AppColors.blueDark,
                        ),
                        const SizedBox(height: 12),
                      ],
                      PushableButton(
                        label: s.backToPath,
                        onPressed: _saving ? null : () => context.go('/'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showCelebration && _award != null)
                Positioned.fill(
                  child: AwardCelebration(
                    award: _award!,
                    isPerfect: result.accuracy >= 1.0,
                    treeCount: _treeCount,
                    onCollect: () => setState(() => _showCelebration = false),
                  ),
                ),
              if (_showDialogue && _award != null)
                Positioned.fill(
                  child: PostLessonComedy(
                    courseId: _courseId,
                    lessonId: widget.lessonId,
                    strings: s,
                    onFinished: () {
                      if (!_sessionCurrent) return;
                      setState(() {
                        _showDialogue = false;
                        _showCelebration = _celebrateAfterComedy;
                        _celebrateAfterComedy = false;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
