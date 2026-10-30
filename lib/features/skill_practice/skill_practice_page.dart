import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/services/diagnostic_log.dart';
import '../../data/models/course.dart';
import '../../data/models/skill_practice.dart';
import '../../data/models/skill_practice_progress.dart';
import '../../data/sources/learning_store.dart';
import '../../data/sources/skill_practice_loader.dart';
import '../feedback/feedback_dialog.dart';
import '../lesson/widgets/answer_feedback_bar.dart';
import '../lesson/widgets/exercise_widget_builder.dart';
import '../lesson/widgets/lesson_style.dart';
import '../lesson/widgets/tappable_phonetic_text.dart';
import 'english_tts_button.dart';
import 'skill_practice_controller.dart';
import 'skill_practice_style.dart';
import 'yoga_audio_button.dart';

/// 专项练习会话页（方案 C：独立壳，不走 LessonPage）
class SkillPracticePage extends ConsumerStatefulWidget {
  const SkillPracticePage({
    super.key,
    required this.skill,
    required this.chapterId,
    this.loader,
  });

  final SkillPracticeKind skill;
  final String chapterId;
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
  SkillPracticeBank? _bank;
  Object? _loadError;
  bool _loading = true;
  bool _completed = false;
  bool _allowExit = false;
  bool _recording = false;
  final Set<String> _attempted = {};
  LearningStore? _learningStore;
  late String _courseId;
  late String _mode;

  Color get _accent => widget.skill.accent;

  IconData get _icon => widget.skill.icon;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _questionStart = _startTime;
    _learningStore = ref.read(learningStoreProvider);
    _courseId = ref.read(courseProvider).id;
    _mode = widget.skill.modeForChapter(widget.chapterId);
    final place =
        '${ref.read(courseProvider).title} · ${widget.skill.title} · ${widget.chapterId}';
    unawaited(
      DiagnosticLog.instance?.rememberLesson(
        route: '/practice/${widget.skill.name}/${widget.chapterId}',
        lesson: place,
      ),
    );
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
      final chapter = bank.chapterById(widget.chapterId);
      if (!mounted) return;
      if (chapter == null) {
        setState(() {
          _loading = false;
          _loadError = ref.read(stringsProvider).cannotStart;
        });
        return;
      }
      final picked = loader.pickChapterSession(bank, widget.chapterId);
      if (picked.isEmpty) {
        setState(() {
          _loading = false;
          _loadError = ref.read(stringsProvider).bankEmpty;
        });
        return;
      }
      final session = SkillPracticeSession(
        skill: widget.skill,
        chapterId: widget.chapterId,
        lesson: Lesson(
          id: 'practice-${widget.skill.name}-${widget.chapterId}',
          title: chapter.title,
          exercises: picked,
        ),
      );
      setState(() {
        _bank = bank;
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
        'mode': _mode,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).recordSaveFailed)),
        );
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
                ? 'practice-${widget.skill.name}-${widget.chapterId}'
                : source.first.id,
            exercise: exercise,
            correct: correct,
            first: _attempted.add(exercise.id),
            elapsedMs: DateTime.now().difference(_questionStart).inMilliseconds,
            mode: _mode,
            skipped: skipped,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).recordSaveFailed)),
        );
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
      unawaited(_finishSession(session, state.correctCount, state.totalCount));
    }
  }

  Future<void> _finishSession(
    SkillPracticeSession session,
    int correctCount,
    int totalCount,
  ) async {
    await _log({
      'kind': 'finish',
      'lessonId': session.lesson.id,
      'correctCount': correctCount,
      'totalCount': totalCount,
      'elapsedMs': DateTime.now().difference(_startTime).inMilliseconds,
    });

    final progressStore = ref.read(skillPracticeProgressStoreProvider);
    final previous = progressStore?.get(widget.skill.name, widget.chapterId);
    final updated = applySkillPracticeSessionResult(
      skill: widget.skill.name,
      chapterId: widget.chapterId,
      correctCount: correctCount,
      totalCount: totalCount,
      previous: previous,
    );
    await progressStore?.save(updated);
    ref.read(skillPracticeProgressRevisionProvider.notifier).state++;

    if (!mounted) return;
    final s = ref.read(stringsProvider);
    final passed = updated.lastAccuracy >= skillPracticePassAccuracy;
    final percent = (updated.lastAccuracy * 100).round();
    final bank = _bank;
    String? nextChapterId;
    if (passed && bank != null) {
      final idx = bank.chapters.indexWhere((c) => c.id == widget.chapterId);
      if (idx >= 0 && idx + 1 < bank.chapters.length) {
        nextChapterId = bank.chapters[idx + 1].id;
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(s.skillDoneTitle(widget.skill)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.firstCorrect(correctCount, totalCount)),
            const SizedBox(height: 8),
            Text(s.practiceAccuracy(percent)),
            const SizedBox(height: 8),
            Text(s.practiceUnlockHint(passed)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveToChapters();
            },
            child: Text(s.practiceBackToChapters),
          ),
          if (!passed)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _restartChapter();
              },
              child: Text(s.practiceRetryChapter),
            ),
          if (passed && nextChapterId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _goChapter(nextChapterId!);
              },
              child: Text(s.practiceNextChapter),
            ),
        ],
      ),
    );
  }

  void _leaveToChapters() {
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.go('/practice/${widget.skill.name}');
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  void _restartChapter() {
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final path = '/practice/${widget.skill.name}/${widget.chapterId}';
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.pushReplacement(path);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SkillPracticePage(
              skill: widget.skill,
              chapterId: widget.chapterId,
              loader: widget.loader,
            ),
          ),
        );
      }
    });
  }

  void _goChapter(String chapterId) {
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final path = '/practice/${widget.skill.name}/$chapterId';
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.pushReplacement(path);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SkillPracticePage(
              skill: widget.skill,
              chapterId: chapterId,
              loader: widget.loader,
            ),
          ),
        );
      }
    });
  }

  Future<void> _onClose() async {
    dismissPhoneticBubble();
    final s = ref.read(stringsProvider);
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.exitPracticeTitle),
        content: Text(s.exitPracticeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.keepPracticing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.exit, style: const TextStyle(color: AppColors.red)),
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
                  'mode': _mode,
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
    final s = ref.watch(stringsProvider);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null || _session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.skillTitle(widget.skill))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError?.toString() ?? s.cannotStart,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.back),
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
                          tooltip: s.quitPractice,
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
                          tooltip: s.feedbackRow,
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
                              '${s.skillTitle(widget.skill)} · ${session.lesson.title}',
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
                      Padding(
                        padding: const EdgeInsets.only(left: 48, top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            s.speakingTip,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.greenDark,
                            ),
                          ),
                        ),
                      ),
                    if (widget.skill == SkillPracticeKind.pronunciation &&
                        exercise.type == ExerciseType.speaking)
                      Padding(
                        padding: const EdgeInsets.only(left: 48, top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            s.pronunciationTip,
                            style: const TextStyle(
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
                    promptAction:
                        widget.skill == SkillPracticeKind.sanskritYoga &&
                            exercise.audioId != null
                        ? YogaAudioButton(audioId: exercise.audioId!)
                        : widget.skill == SkillPracticeKind.englishYoga
                        ? EnglishTtsButton(text: exercise.sentence)
                        : null,
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
                  language: exercise.language,
                )
              else
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: LessonColors.track)),
                  ),
                  child: LessonActionButton(
                    label: s.check,
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
