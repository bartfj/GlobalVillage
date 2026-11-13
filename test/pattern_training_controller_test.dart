import 'package:english_village/data/models/pattern_training.dart';
import 'package:english_village/features/pattern_training/pattern_training_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pattern_training_fixture.dart';

void main() {
  late PatternTraining training;
  late PatternTrainingController controller;
  setUp(() {
    training = PatternTraining.fromJson(patternJson());
    controller = PatternTrainingController(training: training);
  });
  tearDown(() => controller.dispose());
  void finishCorrect() {
    while (!controller.state.finished) {
      controller.submit(controller.state.current.answer);
      controller.next();
    }
  }

  test(
    'six learning items exclude examples and finish with independent success',
    () {
      expect(controller.state.totalCount, 6);
      expect(controller.state.current.id, training.substitution.first.id);
      expect(controller.state.independentSuccess, isFalse);
      finishCorrect();
      expect(controller.state.progress, 1);
      expect(controller.state.firstCorrectCount, 6);
      expect(controller.state.hintedCount, 0);
      expect(controller.state.independentSuccess, isTrue);
    },
  );
  test(
    'substitution mistakes and hints cannot invalidate independent recall',
    () {
      controller.revealHint();
      controller.revealHint();
      expect(controller.state.currentHinted, isTrue);
      expect(controller.submit('wrong'), isFalse);
      expect(controller.state.pendingRetry, isTrue);
      controller.next();
      expect(controller.state.currentHinted, isFalse);
      finishCorrect();
      expect(controller.state.firstCorrectCount, 5);
      expect(controller.state.hintedCount, 1);
      expect(controller.state.independentSuccess, isTrue);
    },
  );
  test('first failure requeues once; second failure exits without scoring', () {
    final id = controller.state.current.id;
    controller.submit('wrong');
    controller.next();
    for (var i = 0; i < 5; i++) {
      controller.submit(controller.state.current.answer);
      controller.next();
    }
    expect(controller.state.current.id, id);
    expect(controller.submit('wrong'), isFalse);
    expect(controller.state.pendingRetry, isFalse);
    controller.next();
    expect(controller.state.finished, isTrue);
    expect(controller.state.firstCorrectCount, 5);
  });
  test(
    'submit and next guards prevent duplicate counts and accidental skips',
    () {
      controller.next();
      final id = controller.state.current.id;
      expect(
        controller.submit('  I WOULD LIKE TEA! '),
        isFalse,
      ); // bank has no alternatives
      controller.submit('I want tea.');
      expect(controller.state.firstCorrectCount, 0);
      expect(controller.state.pendingRetry, isTrue);
      controller.next();
      expect(controller.state.current.id, isNot(id));
      controller.submit('  I WANT TEA! ');
      controller.submit('wrong');
      controller.revealHint(); // hint after submission must not count
      expect(controller.state.firstCorrectCount, 1);
      expect(controller.state.hintedCount, 0);
      controller.next();
      expect(controller.submit(' I WOULD LIKE TEA! '), isTrue);
    },
  );
  test(
    'hinted recall preserves first correctness but cannot count independent',
    () {
      for (var i = 0; i < 2; i++) {
        controller.submit(controller.state.current.answer);
        controller.next();
      }
      controller.revealHint();
      finishCorrect();
      expect(controller.state.firstCorrectCount, 6);
      expect(controller.state.hintedCount, 1);
      expect(controller.state.independentSuccess, isFalse);
    },
  );
  test('recall corrected in same session still requires spaced review', () {
    for (var i = 0; i < 2; i++) {
      controller.submit(controller.state.current.answer);
      controller.next();
    }
    controller.submit('wrong');
    controller.next();
    finishCorrect();
    expect(controller.state.firstCorrectCount, 5);
    expect(controller.state.independentSuccess, isFalse);
  });
  test(
    'review uses two exercises and requires both unaided first successes',
    () {
      controller.dispose();
      controller = PatternTrainingController(
        training: training,
        reviewExercises: training.review.take(2).toList(),
      );
      expect(controller.state.isReview, isTrue);
      expect(controller.state.totalCount, 2);
      finishCorrect();
      expect(controller.state.independentSuccess, isTrue);
      controller.submit('wrong');
      controller.next();
      expect(controller.state.firstCorrectCount, 2);
    },
  );
  test('review hint or initial error always fails independent success', () {
    controller.dispose();
    controller = PatternTrainingController(
      training: training,
      reviewExercises: training.review.take(2).toList(),
    );
    controller.revealHint();
    controller.submit('wrong');
    controller.next();
    finishCorrect();
    expect(controller.state.firstCorrectCount, 1);
    expect(controller.state.hintedCount, 1);
    expect(controller.state.independentSuccess, isFalse);
  });
  test(
    'empty review list means learning while malformed review count rejects',
    () {
      expect(
        PatternTrainingController(
          training: training,
          reviewExercises: [],
        ).state.totalCount,
        6,
      );
      expect(
        () => PatternTrainingController(
          training: training,
          reviewExercises: [training.review.first],
        ),
        throwsArgumentError,
      );
    },
  );
}
