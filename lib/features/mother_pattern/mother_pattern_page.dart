import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/adaptive/adaptive_content_column.dart';
import '../../app/providers.dart';
import '../../core/services/tts_service.dart';
import '../../data/models/course.dart';
import '../../data/sources/mother_pattern_store.dart';
import '../lesson/widgets/award_celebration.dart';
import 'mother_pattern_controller.dart';
import 'mother_pattern_completion.dart';
import 'mother_pattern_providers.dart';
import 'mother_pattern_question.dart';
import 'mother_pattern_result.dart';
import 'mother_pattern_speech.dart';
import 'mother_pattern_study.dart';

class MotherPatternPage extends ConsumerStatefulWidget {
  const MotherPatternPage({
    super.key,
    required this.lessonId,
    this.lesson,
    this.reviewSnapshot,
    this.practice = false,
  });
  final String lessonId;
  final Lesson? lesson;
  final MotherPatternReviewSnapshot? reviewSnapshot;
  final bool practice;
  @override
  ConsumerState<MotherPatternPage> createState() => _MotherPatternPageState();
}

class _MotherPatternPageState extends ConsumerState<MotherPatternPage>
    with WidgetsBindingObserver {
  late final Course _course;
  late final Lesson? _lesson;
  late final MotherPatternStore? _store;
  late final TtsService _voice;
  late final MotherPatternSpeech _speech;
  late final String _sessionId;
  MotherPatternController? _controller;
  MotherPatternState? _state;
  MotherPatternCompletion? _completion;
  VoidCallback? _removeListener;
  final _input = TextEditingController();
  String _answer = '';
  bool _teaching = true;
  bool _interrupted = false;
  bool _transitioning = false;
  bool _saving = false;
  bool _failed = false;
  bool _allowExit = false;
  bool _askingExit = false;
  bool _showAward = false;
  int _audioGeneration = 0;
  int _questionSerial = 0;
  MotherPatternCompletionResult? _saved;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _course = ref.read(courseProvider);
    _lesson = widget.lesson ?? _course.lessonById(widget.lessonId);
    _store = ref.read(motherPatternStoreProvider);
    _voice = ref.read(ttsServiceProvider);
    _speech = ref.read(motherPatternSpeechFactoryProvider)();
    _speech.addListener(_speechChanged);
    final random = Random.secure();
    _sessionId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final lesson = _lesson;
    final store = _store;
    final progress = ref.read(progressRepositoryProvider);
    if (lesson?.patternLesson != null &&
        store != null &&
        (widget.reviewSnapshot == null ||
            (widget.reviewSnapshot!.userKey == store.userKey &&
                widget.reviewSnapshot!.courseId == _course.id &&
                widget.reviewSnapshot!.lessonId == lesson!.id)) &&
        (widget.practice ||
            widget.reviewSnapshot != null ||
            (progress?.isLessonUnlocked(widget.lessonId) ?? false))) {
      _controller = MotherPatternController(
        lesson: lesson!,
        reviewExercises: widget.reviewSnapshot?.exercises,
      );
      _removeListener = _controller!.addListener((state) {
        _state = state;
        if (mounted && !_interrupted) setState(() {});
      });
      _completion = MotherPatternCompletion(
        course: _course,
        lesson: lesson,
        store: store,
        progress: progress,
        rewards: ref.read(rewardRepositoryProvider),
        sessionId: _sessionId,
        reviewSnapshot: widget.reviewSnapshot,
        practice: widget.practice,
      );
      _teaching = widget.reviewSnapshot == null;
    }
  }

  bool get _active =>
      mounted &&
      !_interrupted &&
      widget.lessonId == _lesson?.id &&
      ref.read(motherPatternStoreProvider)?.userKey == _store?.userKey &&
      ref.read(selectedTrackProvider).id == _course.id &&
      ref.read(courseProvider).id == _course.id;
  void _speechChanged() {
    if (mounted && !_interrupted) setState(() {});
  }

  void _interrupt() {
    if (_interrupted) return;
    _interrupted = true;
    ++_audioGeneration;
    unawaited(_speech.cancel());
    unawaited(_voice.stop());
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      ++_audioGeneration;
      unawaited(_speech.cancel());
      unawaited(_voice.stop());
    }
  }

  Future<void> _play(Exercise exercise) async {
    if (!_active) return;
    if (!_teaching) {
      final state = _state!;
      if (state.finished ||
          exercise.id != state.current.id ||
          (state.independentIds.contains(state.current.id) && !state.checked)) {
        return;
      }
    }
    final generation = ++_audioGeneration;
    await _speech.cancel();
    if (!_active || generation != _audioGeneration) return;
    final ok = await _voice.speakExercise(exercise);
    if (!_active || generation != _audioGeneration) {
      return;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(stringsProvider).audioPlaybackFailed(exercise.language),
          ),
        ),
      );
    }
  }

  Future<void> _start() async {
    if (!_active || _transitioning) return;
    _transitioning = true;
    ++_audioGeneration;
    await _voice.stop();
    if (_active) setState(() => _teaching = false);
    _transitioning = false;
  }

  void _submit() {
    if (!_active ||
        _transitioning ||
        _controller == null ||
        _speech.busy ||
        _state!.checked) {
      return;
    }
    final state = _state!;
    final spoken = state.current.type == ExerciseType.speaking;
    final answer = spoken && !state.currentTypedFallback
        ? _speech.transcript
        : _answer;
    if (answer.trim().isEmpty) return;
    _controller!.submit(
      answer,
      modality: spoken
          ? (state.currentTypedFallback
                ? MotherPatternModality.typedFallback
                : MotherPatternModality.spoken)
          : MotherPatternModality.typed,
    );
  }

  bool _questionIs(String exerciseId, int serial) =>
      _state != null &&
      !_state!.finished &&
      _state!.current.id == exerciseId &&
      _questionSerial == serial;

  Future<void> _fallback(String exerciseId, int serial) async {
    if (!_active || _transitioning || !_questionIs(exerciseId, serial)) return;
    final generation = ++_audioGeneration;
    await Future.wait<void>([_speech.cancel(), _voice.stop()]);
    if (!_active ||
        _transitioning ||
        generation != _audioGeneration ||
        !_questionIs(exerciseId, serial)) {
      return;
    }
    _controller!.enableTypedFallback();
    _input.clear();
    _answer = '';
  }

  Future<void> _record() async {
    if (!_active || _transitioning || _speech.busy) return;
    final generation = ++_audioGeneration;
    await _voice.stop();
    if (_active && generation == _audioGeneration) await _speech.start();
  }

  Future<void> _next() async {
    if (!_active || _transitioning || !_state!.checked) return;
    setState(() => _transitioning = true);
    ++_audioGeneration;
    await Future.wait<void>([_speech.cancel(), _voice.stop()]);
    if (!_active) {
      _transitioning = false;
      return;
    }
    _input.clear();
    _answer = '';
    ++_questionSerial;
    _controller!.next();
    setState(() => _transitioning = false);
    if (_state!.finished) await _save();
  }

  Future<void> _save() async {
    if (!_active || _saving || _saved != null || _completion == null) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final saved = await _completion!.save(_state!, isCurrent: () => _active);
      if (!_active) return;
      ref.read(progressRevisionProvider.notifier).state++;
      if (saved.award != null) {
        ref.read(rewardRevisionProvider.notifier).state++;
      }
      setState(() {
        _saved = saved;
        _showAward = saved.award != null;
      });
    } catch (_) {
      if (_active) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exit() async {
    if (_saving || _askingExit) return;
    ++_audioGeneration;
    await Future.wait<void>([_speech.cancel(), _voice.stop()]);
    if (!mounted) return;
    if (_saved == null && !_interrupted) {
      _askingExit = true;
      final s = ref.read(stringsProvider);
      final leave = await showDialog<bool>(
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
              child: Text(s.quitPractice),
            ),
          ],
        ),
      );
      _askingExit = false;
      if (!mounted || leave != true) return;
    }
    if (!mounted) return;
    setState(() => _allowExit = true);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    ref.listen(motherPatternStoreProvider, (_, next) {
      if (next?.userKey != _store?.userKey) _interrupt();
    });
    ref.listen(selectedTrackProvider, (_, next) {
      if (next.id != _course.id) _interrupt();
    });
    ref.listen(courseProvider, (_, next) {
      if (next.id != _course.id) _interrupt();
    });
    if (_controller == null || _interrupted) {
      return Scaffold(
        appBar: AppBar(title: Text(s.motherPatternTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(s.patternUnavailable),
          ),
        ),
      );
    }
    final state = _state!;
    final serial = _questionSerial;
    return PopScope(
      canPop: _allowExit || (_saved != null && !_saving) || _interrupted,
      onPopInvokedWithResult: (popped, result) {
        if (!popped) unawaited(_exit());
      },
      child: AdaptiveContentColumn(
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _teaching
                  ? s.motherPatternTitle
                  : state.isReview
                  ? s.patternReviewTitle
                  : s.motherPatternIndependentTitle,
            ),
            leading: IconButton(
              tooltip: s.back,
              onPressed: _saving ? null : _exit,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_teaching) ...[
                        LinearProgressIndicator(
                          value: state.progress.clamp(0.0, 1.0),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_teaching)
                        MotherPatternStudy(
                          pattern: _lesson!.patternLesson!,
                          strings: s,
                          onPlay: _play,
                          onStart: _start,
                        )
                      else if (state.finished)
                        MotherPatternResult(
                          state: state,
                          strings: s,
                          saved: _saved,
                          saving: _saving,
                          failed: _failed,
                          mainLesson:
                              !widget.practice && widget.reviewSnapshot == null,
                          onRetry: _save,
                          onDone: _exit,
                        )
                      else
                        MotherPatternQuestion(
                          key: ValueKey(_questionSerial),
                          state: state,
                          pattern: _lesson!.patternLesson!,
                          speech: _speech,
                          transitioning: _transitioning,
                          strings: s,
                          input: _input,
                          answer: _answer,
                          onAnswer: (answer) {
                            if (_active &&
                                !_transitioning &&
                                _questionIs(state.current.id, serial)) {
                              setState(() => _answer = answer);
                            }
                          },
                          onHint: _controller!.revealHint,
                          onFallback: () => _fallback(state.current.id, serial),
                          onCheck: _submit,
                          onNext: _next,
                          onPlay: _play,
                          onRecord: _record,
                        ),
                    ],
                  ),
                ),
              ),
              if (_showAward && _saved?.award != null)
                Positioned.fill(
                  child: AwardCelebration(
                    award: _saved!.award!,
                    isPerfect: state.accuracy >= 1,
                    treeCount: _saved!.treeCount,
                    onCollect: () => setState(() => _showAward = false),
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
    WidgetsBinding.instance.removeObserver(this);
    ++_audioGeneration;
    _speech.removeListener(_speechChanged);
    _speech.dispose();
    unawaited(_voice.stop());
    _removeListener?.call();
    _controller?.dispose();
    _input.dispose();
    super.dispose();
  }
}
