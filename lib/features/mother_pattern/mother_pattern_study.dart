import 'package:flutter/material.dart';
import '../../app/app_strings.dart';
import '../../data/models/course.dart';
import '../../data/models/pattern_lesson.dart';

class MotherPatternStudy extends StatelessWidget {
  const MotherPatternStudy({
    super.key,
    required this.pattern,
    required this.strings,
    required this.onPlay,
    required this.onStart,
  });
  final PatternLesson pattern;
  final S strings;
  final Future<void> Function(Exercise) onPlay;
  final VoidCallback onStart;

  Exercise _audio(String id, String text) => Exercise(
    id: id,
    type: ExerciseType.speaking,
    prompt: '',
    sentence: text,
    answer: text,
    audioId: id,
    options: const [],
  );
  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(pattern.frame, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Text(pattern.meaning),
      _heading(context, strings.motherPatternDialogue),
      for (var i = 0; i < pattern.dialogue.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  pattern.dialogue[i].speaker,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(pattern.dialogue[i].text),
                Text(pattern.dialogue[i].translation),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    key: ValueKey('dialogue-audio-$i'),
                    tooltip: strings.playPronunciation,
                    onPressed: () => onPlay(
                      _audio(
                        pattern.dialogue[i].audioId,
                        pattern.dialogue[i].text,
                      ),
                    ),
                    icon: const Icon(Icons.volume_up_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      _heading(context, strings.motherPatternVocabulary),
      for (var i = 0; i < pattern.vocabulary.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(pattern.vocabulary[i].text),
          subtitle: Text(pattern.vocabulary[i].meaning),
          trailing: IconButton(
            key: ValueKey('vocabulary-audio-$i'),
            tooltip: strings.playPronunciation,
            onPressed: () => onPlay(
              _audio(pattern.vocabulary[i].audioId, pattern.vocabulary[i].text),
            ),
            icon: const Icon(Icons.volume_up_outlined),
          ),
        ),
      _heading(context, strings.motherPatternRules),
      Text(pattern.slotRule),
      for (final limit in pattern.limitations)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('• $limit'),
        ),
      if (pattern.examples.isNotEmpty)
        _heading(context, strings.motherPatternExamples),
      for (final e in pattern.examples)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(e.sentence),
          subtitle: Text(e.prompt),
          trailing: IconButton(
            tooltip: strings.playPronunciation,
            onPressed: () => onPlay(e),
            icon: const Icon(Icons.volume_up_outlined),
          ),
        ),
      const SizedBox(height: 24),
      FilledButton(
        key: const ValueKey('pattern-start'),
        onPressed: onStart,
        child: Text(strings.patternStartLesson),
      ),
    ],
  );
}
