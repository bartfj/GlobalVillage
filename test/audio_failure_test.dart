import 'package:english_village/app/providers.dart';
import 'package:english_village/core/services/tts_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/features/lesson/widgets/production_exercise_widget.dart';
import 'package:english_village/features/lesson/widgets/listening_choice_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class UnavailableVoice implements TtsService {
  @override
  Future<bool> speakExercise(Exercise exercise) async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final type in [
    ExerciseType.dictation,
    ExerciseType.listeningWordBank,
    ExerciseType.listeningChoice,
  ]) {
    testWidgets(
      '${type.name} reports failed audio without revealing transcript',
      (tester) async {
        final exercise = Exercise(
          id: 'missing',
          type: type,
          prompt: '听一听',
          sentence: 'Hello there.',
          options: const ['你好', '再见'],
          answer: 'Hello there.',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ttsServiceProvider.overrideWithValue(UnavailableVoice()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: type == ExerciseType.listeningChoice
                    ? ListeningChoiceWidget(
                        exercise: exercise,
                        enabled: true,
                        selected: null,
                        onChanged: (_) {},
                      )
                    : ProductionExerciseWidget(
                        exercise: exercise,
                        enabled: true,
                        onChanged: (_) {},
                      ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('语音播放失败，请检查媒体音量及英语语音服务后重试。'), findsOneWidget);
        expect(find.text(exercise.sentence), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
