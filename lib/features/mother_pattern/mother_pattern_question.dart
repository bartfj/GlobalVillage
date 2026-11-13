import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/app_strings.dart';
import '../../data/models/course.dart';
import '../../data/models/pattern_lesson.dart';
import 'mother_pattern_controller.dart';
import 'mother_pattern_speech.dart';

class MotherPatternQuestion extends StatelessWidget {
  const MotherPatternQuestion({
    super.key,
    required this.state,
    required this.pattern,
    required this.speech,
    required this.strings,
    required this.input,
    required this.answer,
    required this.onAnswer,
    required this.onHint,
    required this.onFallback,
    required this.onCheck,
    required this.onNext,
    required this.onPlay,
    required this.onRecord,
    this.transitioning = false,
  });
  final MotherPatternState state;
  final PatternLesson pattern;
  final MotherPatternSpeech speech;
  final S strings;
  final TextEditingController input;
  final String answer;
  final bool transitioning;
  final ValueChanged<String> onAnswer;
  final VoidCallback onHint, onFallback, onCheck, onNext, onRecord;
  final Future<void> Function(Exercise) onPlay;
  String _phase() => switch (state.isReview
      ? PatternPhaseType.scenario
      : pattern.phaseForExercise(state.current.id)) {
    PatternPhaseType.listening => strings.motherPatternListening,
    PatternPhaseType.chunks => strings.motherPatternChunks,
    PatternPhaseType.repeat => strings.motherPatternRepeat,
    PatternPhaseType.recall => strings.patternRecall,
    _ => strings.patternTransfer,
  };
  @override
  Widget build(BuildContext context) {
    final e = state.current;
    final spoken = e.type == ExerciseType.speaking;
    final repeat = spoken && e.speakingMode == SpeakingMode.repeat;
    final independent = state.independentIds.contains(e.id);
    final correction = state.attemptedIds.contains(e.id) && !state.checked;
    final reference = state.checked || repeat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          correction
              ? strings.motherPatternCorrection(
                  state.exerciseIds.indexOf(e.id) + 1,
                )
              : strings.patternCount(
                  state.exerciseIds.indexOf(e.id) + 1,
                  state.totalCount,
                ),
        ),
        const SizedBox(height: 8),
        Text(_phase(), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        Text(e.prompt, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        if (e.type == ExerciseType.listeningChoice) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: strings.playPronunciation,
              onPressed: () => onPlay(e),
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ),
          for (var i = 0; i < e.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                key: ValueKey('option-${e.id}-$i'),
                onPressed: state.checked || transitioning
                    ? null
                    : () => onAnswer(e.options[i]),
                style: OutlinedButton.styleFrom(
                  backgroundColor: answer == e.options[i]
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
                child: Text(e.options[i]),
              ),
            ),
        ] else if (e.type == ExerciseType.wordBank)
          MotherPatternChunks(
            key: ValueKey(e.id),
            exercise: e,
            enabled: !state.checked && !transitioning,
            onChanged: onAnswer,
          )
        else if (spoken) ...[
          if (repeat)
            Text(e.sentence, style: Theme.of(context).textTheme.titleLarge),
          if (!state.currentTypedFallback) ...[
            if (speech.transcript.isNotEmpty)
              Text(
                state.checked ? speech.transcript : strings.motherPatternReady,
                key: const ValueKey('speech-transcript'),
              ),
            if (!state.checked) ...[
              if (speech.status == MotherPatternSpeechStatus.recording)
                FilledButton.icon(
                  key: const ValueKey('speech-stop'),
                  onPressed: transitioning ? null : speech.finish,
                  icon: const Icon(Icons.stop),
                  label: Text(strings.motherPatternStop),
                )
              else if (speech.busy)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    speech.status == MotherPatternSpeechStatus.preparing
                        ? strings.motherPatternPreparing
                        : strings.motherPatternRecognizing,
                  ),
                )
              else
                FilledButton.icon(
                  key: const ValueKey('speech-start'),
                  onPressed: transitioning ? null : onRecord,
                  icon: const Icon(Icons.mic),
                  label: Text(
                    speech.transcript.isEmpty
                        ? strings.motherPatternRecord
                        : strings.motherPatternRetrySpeech,
                  ),
                ),
              if (speech.status == MotherPatternSpeechStatus.denied)
                Text(strings.motherPatternDenied),
              if (speech.status == MotherPatternSpeechStatus.empty)
                Text(strings.motherPatternEmpty),
              if (speech.status == MotherPatternSpeechStatus.error)
                Text(strings.motherPatternSpeechError),
            ],
          ],
          if (state.currentTypedFallback) ...[
            Text(strings.motherPatternFallbackUsed),
            const SizedBox(height: 12),
            _field(),
          ] else if (state.lastAnswerCorrect != true)
            TextButton(
              key: const ValueKey('typed-fallback'),
              onPressed: transitioning ? null : onFallback,
              child: Text(strings.motherPatternTypedFallback),
            ),
        ] else
          _field(),
        if (!state.checked && independent) ...[
          TextButton.icon(
            key: const ValueKey('pattern-hint'),
            onPressed: state.currentHinted || transitioning ? null : onHint,
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(strings.motherPatternRecallHint),
          ),
          if (state.currentHinted) ...[
            Text(strings.patternHintUsed),
            Text(strings.motherPatternSafeHint),
          ],
        ],
        if (state.checked) ...[
          const SizedBox(height: 16),
          Text(
            state.lastAnswerCorrect!
                ? strings.correct
                : strings.patternTryFrame,
          ),
          if (!repeat)
            Text(e.answer, style: Theme.of(context).textTheme.titleLarge),
          if (state.currentHinted) Text(strings.patternHintUsed),
        ],
        if (reference)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const ValueKey('reference-audio'),
              tooltip: strings.playPronunciation,
              onPressed: transitioning ? null : () => onPlay(e),
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ),
        const SizedBox(height: 20),
        if (state.checked)
          FilledButton(
            key: const ValueKey('pattern-next'),
            onPressed: transitioning ? null : onNext,
            child: Text(strings.continueLabel),
          )
        else
          FilledButton(
            key: const ValueKey('pattern-check'),
            onPressed:
                transitioning ||
                    speech.busy ||
                    (spoken && !state.currentTypedFallback
                            ? speech.transcript
                            : answer)
                        .trim()
                        .isEmpty
                ? null
                : onCheck,
            child: Text(strings.check),
          ),
      ],
    );
  }

  Widget _field() => TextFormField(
    key: const ValueKey('pattern-input'),
    controller: input,
    enabled: !state.checked && !transitioning,
    minLines: 2,
    maxLines: 5,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      border: const OutlineInputBorder(),
      hintText: strings.patternAnswerHint,
    ),
    onChanged: onAnswer,
  );
}

class MotherPatternChunks extends StatefulWidget {
  const MotherPatternChunks({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.onChanged,
  });
  final Exercise exercise;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  State<MotherPatternChunks> createState() => _MotherPatternChunksState();
}

class _MotherPatternChunksState extends State<MotherPatternChunks> {
  final _selected = <int>[];
  late final List<int> _order;
  @override
  void initState() {
    super.initState();
    _order = List.generate(widget.exercise.tokens.length, (i) => i)
      ..shuffle(Random(widget.exercise.id.hashCode));
  }

  void _change(int i) {
    setState(() {
      if (_selected.contains(i)) {
        _selected.remove(i);
      } else {
        _selected.add(i);
      }
    });
    widget.onChanged(
      _selected
          .map((i) => widget.exercise.tokens[i])
          .join(widget.exercise.tokenSeparator),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final i in _selected)
              InputChip(
                label: Text(widget.exercise.tokens[i]),
                onPressed: widget.enabled ? () => _change(i) : null,
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in _order)
            if (!_selected.contains(i))
              ActionChip(
                key: ValueKey('token-${widget.exercise.id}-$i'),
                label: Text(widget.exercise.tokens[i]),
                onPressed: widget.enabled ? () => _change(i) : null,
              ),
        ],
      ),
    ],
  );
}
