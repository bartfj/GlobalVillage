import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/course.dart';
import '../../data/models/pattern_training.dart';

/// The frame is shown during instruction, never in an unhinted recall prompt.
class PatternStudyCard extends ConsumerWidget {
  const PatternStudyCard({
    super.key,
    required this.training,
    required this.onStart,
  });
  final PatternTraining training;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.patternStudy)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              training.frame,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              training.meaning,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(training.slotRule),
            const SizedBox(height: 24),
            for (final example in training.examples) ...[
              PatternExample(training: training, exercise: example),
              const SizedBox(height: 16),
            ],
            FilledButton(onPressed: onStart, child: Text(s.patternStartLesson)),
          ],
        ),
      ),
    );
  }
}

class PatternExample extends ConsumerWidget {
  const PatternExample({
    super.key,
    required this.training,
    required this.exercise,
  });
  final PatternTraining training;
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final sentence = exercise.sentence;
    final slot = sentence.substring(
      training.prefix.length,
      sentence.length - training.suffix.length,
    );
    final style = Theme.of(context).textTheme.titleMedium!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: style,
                children: [
                  TextSpan(
                    text: training.prefix,
                    style: const TextStyle(
                      color: Color(0xff1565c0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: slot,
                    style: const TextStyle(
                      color: Color(0xff2e7d32),
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(
                    text: training.suffix,
                    style: const TextStyle(color: Color(0xff1565c0)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(exercise.prompt),
            IconButton(
              tooltip: s.playPronunciation,
              icon: const Icon(Icons.volume_up_rounded),
              onPressed: () async {
                final ok = await ref
                    .read(ttsServiceProvider)
                    .speakExercise(exercise);
                if (!context.mounted || ok) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(s.audioPlaybackFailed(exercise.language)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
