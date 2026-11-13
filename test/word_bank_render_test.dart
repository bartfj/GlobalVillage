import 'package:english_village/app/theme.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/core/services/tts_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/features/lesson/widgets/word_bank_widget.dart';
import 'package:english_village/features/lesson/widgets/production_exercise_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_overrides.dart';

class _Voice implements TtsService {
  @override
  Future<bool> speakExercise(Exercise exercise) async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('listening word bank preserves multiword blocks', (tester) async {
    const exercise = Exercise(
      id: 'listening_chunks',
      type: ExerciseType.listeningWordBank,
      prompt: '',
      sentence: 'I would like water.',
      options: [],
      answer: 'I would like water.',
      tokens: ['I would like', 'water.'],
    );
    var answer = '';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uiStringsOverride,
          ttsServiceProvider.overrideWithValue(_Voice()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ProductionExerciseWidget(
              exercise: exercise,
              enabled: true,
              onChanged: (value) => answer = value,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('I would like'), findsOneWidget);
    await tester.tap(find.text('I would like'));
    await tester.pump();
    await tester.tap(find.text('water.'));
    await tester.pump();
    expect(answer, 'I would like water.');
  });
  testWidgets('multiword tokens stay together and reconstruct the answer', (
    tester,
  ) async {
    const exercise = Exercise(
      id: 'mp_words',
      type: ExerciseType.wordBank,
      prompt: '我想要一些水。',
      sentence: 'I would like some water.',
      options: [],
      answer: 'I would like some water.',
      tokens: ['I would like', 'some water.'],
    );
    var answer = '';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [uiStringsOverride],
        child: MaterialApp(
          home: Scaffold(
            body: WordBankWidget(
              exercise: exercise,
              enabled: true,
              onChanged: (value) => answer = value,
            ),
          ),
        ),
      ),
    );
    expect(find.text('I would like'), findsOneWidget);
    expect(find.text('would'), findsNothing);
    await tester.tap(find.text('I would like'));
    await tester.pump();
    await tester.tap(find.text('some water.'));
    await tester.pump();
    expect(answer, 'I would like some water.');
    expect(exercise.accepts(answer), isTrue);
  });
  testWidgets('explicit token separator is used for selected blocks', (
    tester,
  ) async {
    const exercise = Exercise(
      id: 'joined',
      type: ExerciseType.wordBank,
      prompt: '',
      sentence: 'hello',
      options: [],
      answer: 'hello',
      tokens: ['hel', 'lo'],
      tokenSeparator: '',
    );
    var answer = '';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [uiStringsOverride],
        child: MaterialApp(
          home: Scaffold(
            body: WordBankWidget(
              exercise: exercise,
              enabled: true,
              onChanged: (value) => answer = value,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('hel'));
    await tester.pump();
    await tester.tap(find.text('lo'));
    await tester.pump();
    expect(answer, 'hello');
  });
  testWidgets('词块组件能渲染出词块', (tester) async {
    const exercise = Exercise(
      id: 'u1l1e4',
      type: ExerciseType.wordBank,
      prompt: '早上好！',
      sentence: 'Good morning!',
      options: [],
      answer: 'Good morning!',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [uiStringsOverride],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: WordBankWidget(
              exercise: exercise,
              enabled: true,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('morning!'), findsOneWidget);
  });
}
