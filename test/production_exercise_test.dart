import 'package:english_village/data/models/course.dart';
import 'package:english_village/features/lesson/lesson_controller.dart';
import 'package:english_village/features/lesson/widgets/production_exercise_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exercise = Exercise(
    id: 'input1',
    type: ExerciseType.translateInput,
    prompt: '我喜欢苹果。',
    sentence: 'I like apples.',
    options: [],
    answer: 'I like apples.',
  );

  testWidgets('translation input hides answer and respects disabled state', (
    tester,
  ) async {
    var answer = '';
    await tester.pumpWidget(
      ProviderScope(
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
    expect(find.text(exercise.prompt), findsOneWidget);
    expect(find.text(exercise.sentence), findsNothing);
    await tester.enterText(find.byType(TextField), 'I like apples.');
    expect(answer, exercise.answer);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProductionExerciseWidget(
              exercise: exercise,
              enabled: false,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  test('typed answers use existing normalization and retry rules', () {
    final controller = LessonController(
      const Lesson(id: 'l', title: 'l', exercises: [exercise]),
    );
    addTearDown(controller.dispose);
    expect(controller.submit('wrong'), isFalse);
    controller.next();
    expect(controller.submit('  i like apples!  '), isTrue);
    expect(controller.state.correctCount, 0);
    controller.next();
    expect(controller.state.finished, isTrue);
  });
}
