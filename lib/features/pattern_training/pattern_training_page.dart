import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/course.dart';
import '../../data/models/pattern_training.dart';
import '../../data/sources/learning_store.dart';
import '../lesson/widgets/word_bank_widget.dart';
import 'pattern_training_controller.dart';

class _PatternSession {
  const _PatternSession(this.training, this.reviewExercises);
  final PatternTraining training;
  final List<Exercise>? reviewExercises;
}

final _controllerProvider = StateNotifierProvider.autoDispose
    .family<PatternTrainingController, PatternTrainingState, _PatternSession>(
      (ref, session) => PatternTrainingController(
        training: session.training,
        reviewExercises: session.reviewExercises,
      ),
    );

/// Independent practice: this page never writes course results or awards.
class PatternTrainingPage extends ConsumerStatefulWidget {
  const PatternTrainingPage({
    super.key,
    required this.lesson,
    this.review = false,
  });
  final Lesson lesson;
  final bool review;

  @override
  ConsumerState<PatternTrainingPage> createState() =>
      _PatternTrainingPageState();
}

class _PatternTrainingPageState extends ConsumerState<PatternTrainingPage> {
  _PatternSession? _session;
  LearningStore? _store;
  late final String _courseId;
  late final String _sessionId;
  String _answer = '';
  int _questionSerial = 0;
  bool _saving = false;
  bool _saved = false;
  bool _saveError = false;
  bool _allowExit = false;
  bool _askingExit = false;
  DateTime? _due;

  @override
  void initState() {
    super.initState();
    _courseId = ref.read(courseProvider).id;
    _store = ref.read(learningStoreProvider);
    final random = Random.secure();
    _sessionId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final training = widget.lesson.patternTraining;
    if (training != null && _store != null) {
      _session = _PatternSession(
        training,
        widget.review
            ? _store!.patternReviewExercises(_courseId, training)
            : null,
      );
    }
  }

  bool get _active =>
      mounted &&
      ref.read(courseProvider).id == _courseId &&
      ref.read(learningStoreProvider)?.userKey == _store?.userKey;

  Future<void> _save() async {
    if (_saving || _saved || !_active || _session == null) return;
    final state = ref.read(_controllerProvider(_session!));
    if (!state.finished) return;
    setState(() {
      _saving = true;
      _saveError = false;
    });
    try {
      final entry = await _store!.recordPatternSession(
        courseId: _courseId,
        lessonId: widget.lesson.id,
        sessionId: _sessionId,
        training: _session!.training,
        review: widget.review,
        independentSuccess: state.independentSuccess,
        firstCorrect: state.firstCorrectCount,
        totalCount: state.totalCount,
        hints: state.hintedCount,
      );
      if (!_active) return;
      setState(() {
        _saved = true;
        _due = entry.due;
      });
    } catch (_) {
      if (_active) setState(() => _saveError = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exit() async {
    if (_saving || _askingExit) return;
    if (!_saved && _session != null && _active) {
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
    Navigator.of(context).pop();
  }

  Future<void> _play(Exercise exercise) async {
    final ok = await ref.read(ttsServiceProvider).speakExercise(exercise);
    if (!mounted || ok) return;
    final s = ref.read(stringsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.audioPlaybackFailed(exercise.language))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final course = ref.watch(courseProvider);
    final store = ref.watch(learningStoreProvider);
    final session = _session;
    if (session == null ||
        course.id != _courseId ||
        store?.userKey != _store?.userKey) {
      return Scaffold(
        appBar: AppBar(title: Text(s.patternTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(s.patternUnavailable),
          ),
        ),
      );
    }
    final state = ref.watch(_controllerProvider(session));
    return PopScope(
      canPop: _allowExit || (_saved && !_saving),
      onPopInvokedWithResult: (popped, result) {
        if (!popped) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.review ? s.patternReviewTitle : s.patternTitle),
          leading: IconButton(
            tooltip: s.back,
            onPressed: _saving ? null : _exit,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: state.progress),
                const SizedBox(height: 20),
                if (state.finished) ...[
                  Text(
                    _saved ? s.patternCompleted : s.practiceDone,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.firstCorrect(state.firstCorrectCount, state.totalCount),
                  ),
                  Text(s.patternHints(state.hintedCount)),
                  if (_due != null) Text(s.patternNextReview(_due!)),
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_saveError) ...[
                    Text(s.recordSaveFailed),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(s.retrySave),
                    ),
                  ],
                  if (_saved)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: FilledButton(
                        onPressed: _exit,
                        child: Text(s.done),
                      ),
                    ),
                ] else
                  ..._question(context, state, session),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _question(
    BuildContext context,
    PatternTrainingState state,
    _PatternSession session,
  ) {
    final s = ref.read(stringsProvider);
    final e = state.current;
    final substitution = e.type == ExerciseType.wordBank;
    final recall = session.training.recall.any((item) => item.id == e.id);
    return [
      Text(
        s.patternCount(
          state.totalCount - state.queue.length + 1,
          state.totalCount,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        substitution
            ? s.patternSubstitution
            : recall
            ? s.patternRecall
            : s.patternTransfer,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 20),
      if (substitution)
        WordBankWidget(
          key: ValueKey(_questionSerial),
          exercise: e,
          enabled: !state.checked,
          onChanged: (value) => setState(() => _answer = value),
        )
      else ...[
        Text(e.prompt, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextFormField(
          key: ValueKey(_questionSerial),
          enabled: !state.checked,
          minLines: 2,
          maxLines: 5,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: s.patternAnswerHint,
          ),
          onChanged: (value) => setState(() => _answer = value),
        ),
      ],
      if (!state.checked) ...[
        TextButton.icon(
          onPressed: state.currentHinted
              ? null
              : () => ref
                    .read(_controllerProvider(session).notifier)
                    .revealHint(),
          icon: const Icon(Icons.lightbulb_outline),
          label: Text(s.patternShowHint),
        ),
        if (state.currentHinted) ...[
          Text(s.patternHintUsed),
          Text(
            session.training.frame,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(session.training.slotRule),
          Text(session.training.examples.first.sentence),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _answer.trim().isEmpty
              ? null
              : () => ref
                    .read(_controllerProvider(session).notifier)
                    .submit(_answer),
          child: Text(s.check),
        ),
      ] else ...[
        const SizedBox(height: 20),
        Text(state.lastAnswerCorrect! ? s.correct : s.patternTryFrame),
        if (!state.lastAnswerCorrect!) Text(session.training.frame),
        Text(e.answer, style: Theme.of(context).textTheme.titleMedium),
        if (state.currentHinted) Text(s.patternHintUsed),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: s.playPronunciation,
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: () => _play(e),
          ),
        ),
        FilledButton(
          onPressed: () {
            ref.read(_controllerProvider(session).notifier).next();
            setState(() {
              _answer = '';
              _questionSerial++;
            });
            if (ref.read(_controllerProvider(session)).finished) _save();
          },
          child: Text(s.continueLabel),
        ),
      ],
    ];
  }
}
