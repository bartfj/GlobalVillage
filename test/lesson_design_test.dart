import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/features/lesson/widgets/answer_feedback_bar.dart';
import 'package:english_village/features/lesson/widgets/lesson_style.dart';
import 'package:english_village/features/lesson/widgets/translate_choice_widget.dart';

const exercise = Exercise(
  id: 'design',
  type: ExerciseType.translateChoice,
  prompt: '请坐下。',
  sentence: 'Sit down, please.',
  options: [
    'Listen, please.',
    'Stand up, please.',
    'Come here, please.',
    'Sit down, please.',
  ],
  answer: 'Sit down, please.',
);

void main() {
  testWidgets('translation selection and checked feedback fit narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: TranslateChoiceWidget(
              exercise: exercise,
              enabled: true,
              selected: null,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    expect(find.text('中文 → 英文'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    await tester.tap(find.text('Stand up, please.'));
    expect(selected, 'Stand up, please.');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: TranslateChoiceWidget(
              exercise: exercise,
              enabled: false,
              selected: selected,
              checked: true,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('Listen, please.'));
    expect(selected, 'Stand up, please.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('feedback displays answer and continues', (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AnswerFeedbackBar(
              correct: true,
              correctAnswer: exercise.answer,
              onContinue: () => continued = true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('回答正确！'), findsOneWidget);
    expect(find.text(exercise.answer), findsOneWidget);
    await tester.tap(find.text('继续'));
    expect(continued, isTrue);
  });

  testWidgets('check action stays disabled without an answer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LessonActionButton(label: '检查', onPressed: null)),
      ),
    );
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
  });
}
