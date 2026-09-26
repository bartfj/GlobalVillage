import 'package:english_village/data/models/course.dart';
import 'package:english_village/features/lesson/lesson_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise _ex(String id, {String answer = 'Hello'}) => Exercise(
      id: id,
      type: ExerciseType.speaking,
      prompt: '跟读',
      answer: answer,
      sentence: answer,
      options: const [],
    );

Lesson _lesson(List<Exercise> exercises) => Lesson(
      id: 'l1',
      title: 't',
      exercises: exercises,
    );

void main() {
  test('skipWithoutCredit 不计正确且不重做，继续后出队', () {
    final controller = LessonController(
      _lesson([_ex('e1'), _ex('e2', answer: 'World')]),
    );

    controller.skipWithoutCredit();

    expect(controller.state.checked, isTrue);
    expect(controller.state.lastAnswerCorrect, isFalse);
    expect(controller.state.skipped, isTrue);
    expect(controller.state.correctCount, 0);
    expect(controller.state.pendingRetry, isFalse);

    controller.next();

    expect(controller.state.finished, isFalse);
    expect(controller.state.current.id, 'e2');
    expect(controller.state.correctCount, 0);
  });

  test('skipWithoutCredit 后正确率按未答对计', () {
    final controller = LessonController(
      _lesson([_ex('e1'), _ex('e2'), _ex('e3')]),
    );
    controller.submit('Hello');
    controller.next();
    controller.skipWithoutCredit();
    controller.next();
    controller.submit('Hello');
    controller.next();

    expect(controller.state.finished, isTrue);
    expect(controller.state.correctCount, 2);
    expect(controller.state.accuracy, closeTo(2 / 3, 0.001));
  });
}
