import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/course.dart';
import '../../data/sources/learning_store.dart';
import '../feedback/feedback_dialog.dart';
import 'lesson_controller.dart';
import 'result_page.dart';
import 'widgets/answer_feedback_bar.dart';
import 'widgets/exercise_widget_builder.dart';
import 'widgets/lesson_style.dart';
import 'widgets/lesson_study_card.dart';
import 'widgets/tappable_phonetic_text.dart';

/// 答题主流程页
class LessonPage extends ConsumerStatefulWidget {
  final String lessonId;
  final Lesson? practiceLesson;
  final String mode;

  const LessonPage({
    super.key,
    required this.lessonId,
    this.practiceLesson,
    this.mode = 'lesson',
  });

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends ConsumerState<LessonPage> {
  String _currentAnswer = '';
  String? _lastPhoneticExerciseId;
  int _questionSerial = 0;
  late final DateTime _startTime;
  late final String _attemptId;

  Lesson? _lesson;
  bool _locked = false;
  bool _completed = false;
  bool _allowExit = false;
  LearningStore? _learningStore;
  late String _courseId;
  bool _recording = false;
  late bool _showStudyCard;
  final Set<String> _attempted = {};
  late DateTime _questionStart;

  @override
  void initState() {
    super.initState();
    _lesson =
        widget.practiceLesson ??
        ref.read(courseRepositoryProvider).lessonById(widget.lessonId);
    // 进入答题页即计时（late final 惰性初始化若首次访问在结算时会得到 0）
    _startTime = DateTime.now();
    _learningStore = ref.read(learningStoreProvider);
    _courseId = ref.read(courseProvider).id;
    // 新文字系统课程（中文、梵文）先展示本课核心内容，避免零基础直接开考。
    _showStudyCard =
        widget.practiceLesson == null &&
        widget.mode == 'lesson' &&
        (_courseId == 'chinese' || _courseId == 'sanskrit');
    _questionStart = _startTime;
    final random = Random.secure();
    _attemptId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    final progress = ref.read(progressRepositoryProvider);
    if (_lesson == null ||
        progress == null ||
        (widget.practiceLesson == null &&
            !progress.isLessonUnlocked(widget.lessonId))) {
      _locked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
    } else {
      unawaited(
        _log({
          'kind': 'start',
          'lessonId': widget.lessonId,
          'mode': widget.mode,
        }),
      );
    }
  }

  Future<void> _log(Map<String, dynamic> event) async {
    try {
      await _learningStore?.log({...event, 'courseId': _courseId});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('学习记录保存失败，请稍后重试。')));
      }
    }
  }

  Future<void> _onCheck() async {
    if (_recording) return;
    final controller = ref.read(lessonControllerProvider(_lesson!).notifier);
    final state = ref.read(lessonControllerProvider(_lesson!));
    if (state.checked) return;
    final exercise = state.current;
    final correct = controller.submit(_currentAnswer);
    final sound = ref.read(soundServiceProvider);
    if (correct) {
      sound.playCorrect();
    } else {
      sound.playWrong();
    }
    await _recordAnswer(exercise, correct);
  }

  Future<void> _recordAnswer(
    Exercise exercise,
    bool correct, {
    bool skipped = false,
  }) async {
    setState(() => _recording = true);
    try {
      final course = ref.read(courseProvider);
      final source = course.orderedLessons.where(
        (l) => l.exercises.any((e) => e.id == exercise.id),
      );
      await ref
          .read(learningStoreProvider)
          ?.recordAnswer(
            courseId: course.id,
            lessonId: source.isEmpty ? widget.lessonId : source.first.id,
            exercise: exercise,
            correct: correct,
            first: _attempted.add(exercise.id),
            elapsedMs: DateTime.now().difference(_questionStart).inMilliseconds,
            mode: widget.mode,
            skipped: skipped,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('学习记录保存失败，请稍后重试。')));
      }
    } finally {
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _onSkipSpeaking() async {
    if (_recording) return;
    final controller = ref.read(lessonControllerProvider(_lesson!).notifier);
    final exercise = ref.read(lessonControllerProvider(_lesson!)).current;
    controller.skipWithoutCredit();
    setState(() => _currentAnswer = '');
    await _recordAnswer(exercise, false, skipped: true);
  }

  void _onContinue() {
    if (_recording) return;
    final controller = ref.read(lessonControllerProvider(_lesson!).notifier);
    controller.next();
    _currentAnswer = '';
    _questionSerial++;
    _questionStart = DateTime.now();
    final state = ref.read(lessonControllerProvider(_lesson!));
    if (state.finished) {
      _completed = true;
      unawaited(
        _log({
          'kind': 'finish',
          'lessonId': widget.lessonId,
          'mode': widget.mode,
          'correctCount': state.correctCount,
          'totalCount': state.totalCount,
          'elapsedMs': DateTime.now().difference(_startTime).inMilliseconds,
        }),
      );
      if (widget.practiceLesson != null) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('练习完成'),
            content: Text('首次答对 ${state.correctCount} / ${state.totalCount}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _allowExit = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) Navigator.of(this.context).pop();
                  });
                },
                child: const Text('完成'),
              ),
            ],
          ),
        );
        return;
      }
      final elapsed = DateTime.now().difference(_startTime).inSeconds;
      context.replace(
        '/lesson/${widget.lessonId}/result',
        extra: LessonResult(
          correctCount: state.correctCount,
          totalCount: state.totalCount,
          elapsedSeconds: elapsed,
          attemptId: _attemptId,
        ),
      );
    }
  }

  Future<void> _onClose() async {
    dismissPhoneticBubble();
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出练习？'),
        content: const Text('本次练习的进度将不会保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续学习'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (quit == true && mounted) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final lesson = _lesson;
    if (lesson == null) {
      return const Scaffold(body: Center(child: Text('课程不存在')));
    }
    if (_showStudyCard) {
      return LessonStudyCard(
        lesson: lesson,
        onStart: () => setState(() => _showStudyCard = false),
      );
    }
    final state = ref.watch(lessonControllerProvider(lesson));
    if (state.finished) {
      if (widget.practiceLesson != null) {
        return const Scaffold(
          body: Center(
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: LessonColors.green,
            ),
          ),
        );
      }
      // 等待 _onContinue 跳转，避免闪现空页面
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final exercise = state.current;
    final questionKey = ValueKey('${exercise.id}#$_questionSerial');
    if (_lastPhoneticExerciseId != exercise.id) {
      _lastPhoneticExerciseId = exercise.id;
      dismissPhoneticBubble();
    }

    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onClose();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 24, 18),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: LessonColors.track)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: LessonColors.muted,
                          ),
                          tooltip: '退出练习',
                          onPressed: _onClose,
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: state.progress,
                            color: LessonColors.green,
                            backgroundColor: LessonColors.track,
                            borderRadius: BorderRadius.circular(6),
                            minHeight: 12,
                            semanticsLabel: '已完成题数',
                            semanticsValue: '${(state.progress * 100).round()}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${state.totalCount - state.queue.length} / ${state.totalCount}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: LessonColors.muted,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.feedback_outlined,
                            color: LessonColors.muted,
                          ),
                          tooltip: '反馈问题',
                          onPressed: () => showFeedbackDialog(context, ref),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 48, top: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.spa_outlined,
                            size: 15,
                            color: LessonColors.greenDark,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${ref.read(courseRepositoryProvider).course.title} · ${lesson.title}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: LessonColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 27, 24, 16),
                  child: _buildExercise(exercise, state, questionKey),
                ),
              ),
              if (state.checked)
                AnswerFeedbackBar(
                  correct: state.lastAnswerCorrect!,
                  skipped: state.skipped,
                  correctAnswer: exercise.type == ExerciseType.matchPairs
                      ? MatchPair.formatForDisplay(exercise.answer)
                      : exercise.answer,
                  onContinue: _onContinue,
                )
              else
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: LessonColors.track)),
                  ),
                  child: LessonActionButton(
                    label: '检查',
                    onPressed: _currentAnswer.trim().isEmpty || _recording
                        ? null
                        : _onCheck,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (!_completed && !_locked) {
      // Capture providers before disposing; async writes do not retain WidgetRef.
      final store = _learningStore;
      unawaited(
        store
                ?.log({
                  'kind': 'exit',
                  'lessonId': widget.lessonId,
                  'mode': widget.mode,
                  'courseId': _courseId,
                  'elapsedMs': DateTime.now()
                      .difference(_startTime)
                      .inMilliseconds,
                })
                .catchError((Object _) {}) ??
            Future<void>.value(),
      );
    }
    super.dispose();
  }

  Widget _buildExercise(Exercise exercise, LessonState state, Key questionKey) {
    return buildExerciseWidget(
      exercise: exercise,
      enabled: !state.checked,
      checked: state.checked,
      currentAnswer: _currentAnswer,
      onChanged: (v) => setState(() => _currentAnswer = v),
      questionKey: questionKey,
      onSkipSpeaking: _onSkipSpeaking,
    );
  }
}
