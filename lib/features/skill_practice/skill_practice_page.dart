import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/course.dart';
import '../../data/models/skill_practice.dart';
import '../../data/sources/learning_store.dart';
import '../../data/sources/skill_practice_loader.dart';
import '../feedback/feedback_dialog.dart';
import '../lesson/widgets/answer_feedback_bar.dart';
import '../lesson/widgets/exercise_widget_builder.dart';
import '../lesson/widgets/lesson_style.dart';
import '../lesson/widgets/tappable_phonetic_text.dart';
import 'skill_practice_controller.dart';

/// 专项练习会话页（方案 C：独立壳，不走 LessonPage）
class SkillPracticePage extends ConsumerStatefulWidget {
  const SkillPracticePage({super.key, required this.skill, this.loader});

  final SkillPracticeKind skill;
  final SkillPracticeLoader? loader;

  @override
  ConsumerState<SkillPracticePage> createState() => _SkillPracticePageState();
}

class _SkillPracticePageState extends ConsumerState<SkillPracticePage> {
  String _currentAnswer = '';
  String? _lastPhoneticExerciseId;
  int _questionSerial = 0;
  late final DateTime _startTime;
  late DateTime _questionStart;

  SkillPracticeSession? _session;
  Object? _loadError;
  bool _loading = true;
  bool _completed = false;
  bool _allowExit = false;
  bool _recording = false;
  final Set<String> _attempted = {};
  LearningStore? _learningStore;
  late String _courseId;

  Color get _accent {
    switch (widget.skill) {
      case SkillPracticeKind.pronunciation:
        return AppColors.blue;
      case SkillPracticeKind.vocabulary:
        return AppColors.goldDark;
      case SkillPracticeKind.speaking:
        return AppColors.green;
    }
  }

  IconData get _icon {
    switch (widget.skill) {
      case SkillPracticeKind.pronunciation:
        return Icons.hearing_rounded;
      case SkillPracticeKind.vocabulary:
        return Icons.menu_book_rounded;
      case SkillPracticeKind.speaking:
        return Icons.record_voice_over_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _questionStart = _startTime;
    _learningStore = ref.read(learningStoreProvider);
    _courseId = ref.read(courseProvider).id;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final loader =
        widget.loader ??
        SkillPracticeLoader(
          documents: await ref.read(contentCacheProvider.future),
        );
    try {
      final bank = await loader.load(widget.skill);
      final picked = loader.pickSession(bank.exercises);
      if (!mounted) return;
      if (picked.isEmpty) {
        setState(() {
          _loading = false;
          _loadError = '题库为空';
        });
        return;
      }
      final session = SkillPracticeSession(
        skill: widget.skill,
        lesson: Lesson(
          id: 'practice-${widget.skill.name}',
          title: bank.title,
          exercises: picked,
        ),
      );
      setState(() {
        _session = session;
        _loading = false;
      });
      await _log({'kind': 'start', 'lessonId': session.lesson.id});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  Future<void> _log(Map<String, dynamic> event) async {
    try {
      await _learningStore?.log({
        ...event,
        'courseId': _courseId,
        'mode': widget.skill.mode,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('学习记录保存失败，请稍后重试。')));
      }
    }
  }

  Future<void> _onCheck() async {
    final session = _session;
    if (session == null || _recording) return;
    final controller = ref.read(
      skillPracticeControllerProvider(session).notifier,
    );
    final state = ref.read(skillPracticeControllerProvider(session));
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
            lessonId: source.isEmpty
                ? 'practice-${widget.skill.name}'
                : source.first.id,
            exercise: exercise,
            correct: correct,
            first: _attempted.add(exercise.id),
            elapsedMs: DateTime.now().difference(_questionStart).inMilliseconds,
            mode: widget.skill.mode,
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
    final session = _session;
    if (session == null || _recording) return;
    final controller = ref.read(
      skillPracticeControllerProvider(session).notifier,
    );
    final exercise = ref.read(skillPracticeControllerProvider(session)).current;
    controller.skipWithoutCredit();
    setState(() => _currentAnswer = '');
    await _recordAnswer(exercise, false, skipped: true);
  }

  void _onContinue() {
    final session = _session;
    if (session == null || _recording) return;
    final controller = ref.read(
      skillPracticeControllerProvider(session).notifier,
    );
    controller.next();
    _currentAnswer = '';
    _questionSerial++;
    _questionStart = DateTime.now();
    final state = ref.read(skillPracticeControllerProvider(session));
    if (state.finished) {
      _completed = true;
      unawaited(
        _log({
          'kind': 'finish',
          'lessonId': session.lesson.id,
          'correctCount': state.correctCount,
          'totalCount': state.totalCount,
          'elapsedMs': DateTime.now().difference(_startTime).inMilliseconds,
        }),
      );
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(widget.skill.doneTitle),
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
            child: const Text('继续练习'),
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
  void dispose() {
    if (!_completed && !_loading && _session != null) {
      final store = _learningStore;
      unawaited(
        store
                ?.log({
                  'kind': 'exit',
                  'lessonId': _session!.lesson.id,
                  'mode': widget.skill.mode,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null || _session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.skill.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError?.toString() ?? '无法开始练习',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final session = _session!;
    final state = ref.watch(skillPracticeControllerProvider(session));
    if (state.finished) {
      return Scaffold(
        body: Center(
          child: Icon(Icons.check_circle_outline, size: 64, color: _accent),
        ),
      );
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
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: LessonColors.track)),
                  color: _accent.withValues(alpha: 0.06),
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
                            color: _accent,
                            backgroundColor: LessonColors.track,
                            borderRadius: BorderRadius.circular(6),
                            minHeight: 12,
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
                          Icon(_icon, size: 16, color: _accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${widget.skill.title} · ${widget.skill.subtitle}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: LessonColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.skill == SkillPracticeKind.speaking)
                      const Padding(
                        padding: EdgeInsets.only(left: 48, top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '提示：尽量大声说出来',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.greenDark,
                            ),
                          ),
                        ),
                      ),
                    if (widget.skill == SkillPracticeKind.pronunciation &&
                        exercise.type == ExerciseType.speaking)
                      const Padding(
                        padding: EdgeInsets.only(left: 48, top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '听原音后跟读，注意语音相似度',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.blueDark,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 27, 24, 16),
                  child: buildExerciseWidget(
                    exercise: exercise,
                    enabled: !state.checked,
                    checked: state.checked,
                    currentAnswer: _currentAnswer,
                    onChanged: (v) => setState(() => _currentAnswer = v),
                    questionKey: questionKey,
                    onSkipSpeaking: _onSkipSpeaking,
                  ),
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
}
