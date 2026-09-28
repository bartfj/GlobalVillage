import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../data/models/lesson_badge.dart';
import '../../data/repositories/reward_repository.dart';
import 'widgets/award_celebration.dart';
import 'widgets/dialogue_performance.dart';

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

  @override
  void initState() {
    super.initState();
    // 回写学习结果并驱动学习路径刷新
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveResult());
  }

  Future<void> _saveResult() async {
    if (_saving || _saved) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await ref
          .read(progressRepositoryProvider)
          .recordResult(
            lessonId: widget.lessonId,
            correctCount: widget.result.correctCount,
            totalCount: widget.result.totalCount,
          );
      if (!mounted) return;
      ref.read(progressRevisionProvider.notifier).state++;
      if (widget.result.passed) {
        final repo = ref.read(rewardRepositoryProvider);
        final award = await repo.awardForPassedAttempt(
          widget.lessonId,
          widget.result.attemptId,
        );
        if (award == null) throw StateError('无法保存徽章奖励');
        if (!mounted) return;
        ref.read(rewardRevisionProvider.notifier).state++;
        setState(() {
          _award = award;
          _treeCount = repo.treeCount;
          // 每次通关都播放趣味对话 + 庆祝（不只首次发徽章时）
          _showDialogue = true;
        });
      }
      _saved = true;
    } catch (_) {
      if (mounted) setState(() => _saveError = '保存失败，请重试');
    } finally {
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final passed = result.passed;
    final minutes = result.elapsedSeconds ~/ 60;
    final seconds = result.elapsedSeconds % 60;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(),
                    Icon(
                      passed
                          ? Icons.emoji_events_rounded
                          : Icons.refresh_rounded,
                      size: 96,
                      color: passed ? AppColors.gold : AppColors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      passed ? '课程完成！' : '再练一次吧！',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      passed ? '下一课已解锁' : '正确率达到 70% 即可解锁下一课',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        _StatCard(
                          label: '得分',
                          value: '${result.score}',
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: '正确率',
                          value: '${(result.accuracy * 100).round()}%',
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: '用时',
                          value: '$minutes分$seconds秒',
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
                              LessonBadgeStyle.forLesson(_award!.lesson.id).icon,
                              size: 48,
                              color: LessonBadgeStyle.forLesson(
                                _award!.lesson.id,
                              ).color,
                            ),
                            Text(
                              '${_award!.lesson.title}徽章 ${_award!.newlyAwarded ? '+1' : '已领取'}',
                            ),
                            Text('本关累计 ${_award!.count} 枚'),
                            if (_treeCount > 0)
                              Text('梭梭树 +1 · 累计 $_treeCount 棵'),
                          ],
                        ),
                      ),
                      if (_award!.newlyAwarded)
                        TextButton.icon(
                          onPressed: () => setState(() => _showDialogue = true),
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('重播对话'),
                        ),
                    ],
                    if (_saveError != null) ...[
                      Text(
                        _saveError!,
                        style: const TextStyle(color: AppColors.red),
                      ),
                      TextButton(
                        onPressed: _saveResult,
                        child: const Text('重试保存'),
                      ),
                    ],
                    const Spacer(),
                    if (!passed) ...[
                      PushableButton(
                        label: '重新学习',
                        onPressed: () =>
                            context.replace('/lesson/${widget.lessonId}'),
                        color: AppColors.blue,
                        shadowColor: AppColors.blueDark,
                      ),
                      const SizedBox(height: 12),
                    ],
                    PushableButton(
                      label: '返回学习路径',
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
                child: DialoguePerformance(
                  unitId: _award!.unit.id,
                  unitTitle: _award!.unit.title,
                  onFinished: () => setState(() {
                    _showDialogue = false;
                    _showCelebration = true;
                  }),
                ),
              ),
          ],
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
