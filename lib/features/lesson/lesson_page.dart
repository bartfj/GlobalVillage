import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/course.dart';
import 'lesson_controller.dart';
import 'result_page.dart';
import 'widgets/answer_feedback_bar.dart';
import 'widgets/fill_blank_widget.dart';
import 'widgets/listening_choice_widget.dart';
import 'widgets/speaking_widget.dart';
import 'widgets/translate_choice_widget.dart';
import 'widgets/word_bank_widget.dart';

/// 答题主流程页
class LessonPage extends ConsumerStatefulWidget {
  final String lessonId;

  const LessonPage({super.key, required this.lessonId});

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends ConsumerState<LessonPage> {
  String _currentAnswer = '';
  int _questionSerial = 0;
  late final DateTime _startTime;
  late final String _attemptId;

  Lesson? _lesson;

  @override
  void initState() {
    super.initState();
    _lesson = ref.read(courseRepositoryProvider).lessonById(widget.lessonId);
    // 进入答题页即计时（late final 惰性初始化若首次访问在结算时会得到 0）
    _startTime = DateTime.now();
    final random = Random.secure();
    _attemptId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void _onCheck() {
    final controller = ref.read(lessonControllerProvider(_lesson!).notifier);
    final correct = controller.submit(_currentAnswer);
    final sound = ref.read(soundServiceProvider);
    if (correct) {
      sound.playCorrect();
    } else {
      sound.playWrong();
    }
  }

  void _onContinue() {
    final controller = ref.read(lessonControllerProvider(_lesson!).notifier);
    controller.next();
    _currentAnswer = '';
    _questionSerial++;
    final state = ref.read(lessonControllerProvider(_lesson!));
    if (state.finished) {
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
    if (quit == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    if (lesson == null) {
      return const Scaffold(body: Center(child: Text('课程不存在')));
    }
    final state = ref.watch(lessonControllerProvider(lesson));
    if (state.finished) {
      // 等待 _onContinue 跳转，避免闪现空页面
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final exercise = state.current;
    final questionKey = ValueKey('${exercise.id}#$_questionSerial');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.lockedDark,
                    ),
                    onPressed: _onClose,
                  ),
                  Expanded(
                    child: LinearProgressIndicator(value: state.progress),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: _buildExercise(exercise, state, questionKey),
              ),
            ),
            if (state.checked)
              AnswerFeedbackBar(
                correct: state.lastAnswerCorrect!,
                correctAnswer: exercise.answer,
                onContinue: _onContinue,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: PushableButton(
                  label: '检查',
                  onPressed: _currentAnswer.trim().isEmpty ? null : _onCheck,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercise(Exercise exercise, LessonState state, Key questionKey) {
    final enabled = !state.checked;
    switch (exercise.type) {
      case ExerciseType.translateChoice:
        return TranslateChoiceWidget(
          key: questionKey,
          exercise: exercise,
          enabled: enabled,
          selected: _currentAnswer.isEmpty ? null : _currentAnswer,
          onChanged: (v) => setState(() => _currentAnswer = v),
        );
      case ExerciseType.listeningChoice:
        return ListeningChoiceWidget(
          key: questionKey,
          exercise: exercise,
          enabled: enabled,
          selected: _currentAnswer.isEmpty ? null : _currentAnswer,
          onChanged: (v) => setState(() => _currentAnswer = v),
        );
      case ExerciseType.wordBank:
        return WordBankWidget(
          key: questionKey,
          exercise: exercise,
          enabled: enabled,
          onChanged: (v) => setState(() => _currentAnswer = v),
        );
      case ExerciseType.fillBlank:
        return FillBlankWidget(
          key: questionKey,
          exercise: exercise,
          enabled: enabled,
          onChanged: (v) => setState(() => _currentAnswer = v),
        );
      case ExerciseType.speaking:
        return SpeakingWidget(
          key: questionKey,
          exercise: exercise,
          enabled: enabled,
          onChanged: (v) => setState(() => _currentAnswer = v),
        );
    }
  }
}
