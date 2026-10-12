import 'package:flutter/material.dart';

import '../../../data/models/course.dart';
import 'fill_blank_widget.dart';
import 'listening_choice_widget.dart';
import 'match_pairs_widget.dart';
import 'production_exercise_widget.dart';
import 'speaking_widget.dart';
import 'translate_choice_widget.dart';
import 'word_bank_widget.dart';

/// 按题型挂载现有练习 Widget（课时页与专项练习共用）
Widget buildExerciseWidget({
  required Exercise exercise,
  required bool enabled,
  required bool checked,
  required String currentAnswer,
  required ValueChanged<String> onChanged,
  required Key questionKey,
  VoidCallback? onSkipSpeaking,
}) {
  switch (exercise.type) {
    case ExerciseType.listeningWordBank:
    case ExerciseType.dictation:
    case ExerciseType.translateInput:
      return ProductionExerciseWidget(
        key: questionKey,
        exercise: exercise,
        enabled: enabled,
        onChanged: onChanged,
      );
    case ExerciseType.translateChoice:
      return TranslateChoiceWidget(
        key: questionKey,
        exercise: exercise,
        enabled: enabled,
        selected: currentAnswer.isEmpty ? null : currentAnswer,
        checked: checked,
        onChanged: onChanged,
      );
    case ExerciseType.listeningChoice:
      return ListeningChoiceWidget(
        key: questionKey,
        exercise: exercise,
        enabled: enabled,
        selected: currentAnswer.isEmpty ? null : currentAnswer,
        onChanged: onChanged,
      );
    case ExerciseType.wordBank:
      return WordBankWidget(
        key: questionKey,
        exercise: exercise,
        enabled: enabled,
        onChanged: onChanged,
      );
    case ExerciseType.fillBlank:
      return FillBlankWidget(
        key: questionKey,
        exercise: exercise,
        enabled: enabled,
        onChanged: onChanged,
      );
    case ExerciseType.speaking:
      return SpeakingWidget(
        key: questionKey,
        exercise: exercise,
        enabled: enabled,
        onChanged: onChanged,
        onSkip: onSkipSpeaking,
      );
    case ExerciseType.matchPairs:
      return MatchPairsWidget(
        key: questionKey,
        exercise: exercise,
        enabled: enabled,
        onChanged: onChanged,
      );
  }
}
