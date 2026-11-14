import 'package:flutter/material.dart';
import '../../app/app_strings.dart';
import '../../data/sources/mother_pattern_store.dart';
import 'mother_pattern_completion.dart';
import 'mother_pattern_controller.dart';

class MotherPatternResult extends StatelessWidget {
  const MotherPatternResult({
    super.key,
    required this.state,
    required this.strings,
    required this.saved,
    required this.saving,
    required this.failed,
    required this.mainLesson,
    required this.onRetry,
    required this.onDone,
    this.onComedyReplay,
  });
  final MotherPatternState state;
  final S strings;
  final MotherPatternCompletionResult? saved;
  final bool saving, failed, mainLesson;
  final VoidCallback onRetry, onDone;
  final VoidCallback? onComedyReplay;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        saved == null ? strings.practiceDone : strings.patternCompleted,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      Text(strings.firstCorrect(state.firstCorrectCount, state.totalCount)),
      Text(
        strings.motherPatternIndependent(
          state.independentCorrectCount,
          state.independentIds.length,
        ),
      ),
      Text(strings.motherPatternSpoken(state.independentSpokenCorrectCount)),
      Text(strings.motherPatternTyped(state.independentTypedCorrectCount)),
      Text(
        strings.motherPatternFallback(
          state.independentTypedFallbackCorrectCount,
        ),
      ),
      Text(strings.patternHints(state.hintedCount)),
      if (state.typedFallbackIds.isNotEmpty)
        Text(strings.motherPatternFallbackUsed),
      if (saved != null) ...[
        const SizedBox(height: 16),
        Text(switch (saved!.record.reason) {
          MotherPatternSaveReason.dueReview => strings.motherPatternDueSaved,
          MotherPatternSaveReason.practice =>
            strings.motherPatternPracticeSaved,
          MotherPatternSaveReason.staleReview =>
            strings.motherPatternStaleSaved,
          MotherPatternSaveReason.dialogue =>
            strings.motherPatternDialogueSaved,
          MotherPatternSaveReason.learning =>
            mainLesson
                ? (state.accuracy >= .7
                      ? strings.lessonPassed
                      : strings.lessonFailed)
                : strings.motherPatternLearningContext,
        }),
        if (saved!.record.entry != null)
          Text(strings.patternNextReview(saved!.record.entry!.due)),
        if (saved!.award != null) ...[
          Text(
            strings.badgeEarned(
              saved!.award!.lesson.title,
              saved!.award!.newlyAwarded,
            ),
          ),
          Text(strings.treePlusOne(saved!.treeCount)),
        ],
      ],
      if (saving)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(strings.motherPatternSaving),
        ),
      if (failed) ...[
        const SizedBox(height: 16),
        Text(strings.recordSaveFailed),
        FilledButton(
          key: const ValueKey('pattern-save'),
          onPressed: saving ? null : onRetry,
          child: Text(strings.retrySave),
        ),
      ],
      if (saved != null)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: FilledButton(onPressed: onDone, child: Text(strings.done)),
        ),
      if (onComedyReplay != null)
        TextButton.icon(
          key: const ValueKey('replay-pattern-comedy'),
          onPressed: onComedyReplay,
          icon: const Icon(Icons.replay_rounded),
          label: Text(strings.comedyReplay),
        ),
    ],
  );
}
