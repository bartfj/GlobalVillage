import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/course.dart';
import 'word_bank_widget.dart';

/// Audio-only prompts deliberately hide both the transcript and its translation.
class ProductionExerciseWidget extends ConsumerStatefulWidget {
  final Exercise exercise;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const ProductionExerciseWidget({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.onChanged,
  });

  @override
  ConsumerState<ProductionExerciseWidget> createState() =>
      _ProductionExerciseWidgetState();
}

class _ProductionExerciseWidgetState
    extends ConsumerState<ProductionExerciseWidget> {
  final _controller = TextEditingController();
  bool get _audio => widget.exercise.type != ExerciseType.translateInput;

  @override
  void initState() {
    super.initState();
    if (_audio) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play();
      });
    }
  }

  void _play() {
    ref.read(ttsServiceProvider).speakExercise(widget.exercise);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final wordBank = exercise.type == ExerciseType.listeningWordBank;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_audio) ...[
          Text(
            wordBank ? '听音组句' : '听写句子',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Center(
            child: IconButton.filled(
              tooltip: '播放语音',
              iconSize: 40,
              onPressed: _play,
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Text('用英文表达', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(exercise.prompt, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
        ],
        if (wordBank)
          WordBankWidget(
            showPrompt: false,
            exercise: Exercise(
              id: exercise.id,
              type: ExerciseType.wordBank,
              prompt: '',
              sentence: exercise.sentence,
              options: const [],
              answer: exercise.answer,
            ),
            enabled: widget.enabled,
            onChanged: widget.onChanged,
          )
        else
          TextField(
            controller: _controller,
            enabled: widget.enabled,
            minLines: 2,
            maxLines: 5,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '输入英文句子',
            ),
            onChanged: widget.onChanged,
          ),
      ],
    );
  }
}
