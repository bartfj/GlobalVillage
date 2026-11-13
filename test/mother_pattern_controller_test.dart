import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Course motherCourse() => Course.fromJson(
  jsonDecode(
        File('assets/courses/course_mother_pattern.json').readAsStringSync(),
      )
      as Map<String, dynamic>,
);

MotherPatternModality modalityFor(Exercise exercise) =>
    exercise.type == ExerciseType.speaking
    ? MotherPatternModality.spoken
    : MotherPatternModality.typed;

void finishMother(MotherPatternController controller) {
  while (!controller.state.finished) {
    controller.submit(
      controller.state.current.answer,
      modality: modalityFor(controller.state.current),
    );
    controller.next();
  }
}

void main() {
  late Lesson lesson;
  late MotherPatternController controller;
  setUp(() {
    lesson = motherCourse().orderedLessons.first;
    controller = MotherPatternController(lesson: lesson);
  });
  tearDown(() => controller.dispose());

  test(
    'ten-item lesson excludes supplementary tasks and scores four independent IDs',
    () {
      expect(controller.state.totalCount, 10);
      expect(controller.state.independentIds, {
        'mp_u1l1_e7',
        'mp_u1l1_e8',
        'mp_u1l1_e9',
        'mp_u1l1_e10',
      });
      expect(controller.state.independentSuccess, isFalse);
      finishMother(controller);
      expect(controller.state.firstCorrectCount, 10);
      expect(controller.state.progress, 1);
      expect(controller.state.independentSuccess, isTrue);
      expect(controller.state.firstSpokenCorrectCount, 4);
      expect(controller.state.firstTypedCorrectCount, 6);
      expect(controller.state.firstTypedFallbackCorrectCount, 0);
    },
  );

  test(
    'mistake on supported stage requeues once without invalidating independent evidence',
    () {
      controller.revealHint();
      controller.revealHint();
      expect(
        controller.submit('wrong', modality: MotherPatternModality.typed),
        isFalse,
      );
      expect(controller.state.pendingRetry, isTrue);
      controller.next();
      finishMother(controller);
      expect(controller.state.firstCorrectCount, 9);
      expect(controller.state.hintedCount, 1);
      expect(controller.state.attempts, hasLength(11));
      expect(controller.state.independentSuccess, isTrue);
    },
  );

  test(
    'hint on any of four independent tasks prevents independent success',
    () {
      for (var i = 0; i < 6; i++) {
        controller.submit(
          controller.state.current.answer,
          modality: modalityFor(controller.state.current),
        );
        controller.next();
      }
      controller.revealHint();
      finishMother(controller);
      expect(controller.state.firstCorrectCount, 10);
      expect(controller.state.hintedIds, {'mp_u1l1_e7'});
      expect(controller.state.independentSuccess, isFalse);
    },
  );

  test(
    'duplicate submit and premature next cannot change first evidence or skip',
    () {
      controller.next();
      expect(controller.state.current.id, 'mp_u1l1_e1');
      controller.submit('wrong', modality: MotherPatternModality.typed);
      controller.submit(
        controller.state.current.answer,
        modality: MotherPatternModality.typed,
      );
      controller.revealHint();
      expect(controller.state.firstCorrectCount, 0);
      expect(controller.state.attempts, hasLength(1));
      expect(controller.state.hintedCount, 0);
      controller.next();
      for (var i = 0; i < 9; i++) {
        controller.submit(
          controller.state.current.answer,
          modality: modalityFor(controller.state.current),
        );
        controller.next();
      }
      controller.submit('wrong', modality: MotherPatternModality.typed);
      expect(controller.state.pendingRetry, isFalse);
      controller.next();
      expect(controller.state.finished, isTrue);
      expect(controller.state.firstCorrectCount, 9);
    },
  );

  test('two-item review requires both unaided first successes', () {
    controller.dispose();
    controller = MotherPatternController(
      lesson: lesson,
      reviewExercises: lesson.patternLesson!.review.take(2).toList(),
    );
    expect(controller.state.totalCount, 2);
    expect(controller.state.isReview, isTrue);
    controller.revealHint();
    controller.submit('wrong', modality: MotherPatternModality.spoken);
    controller.next();
    finishMother(controller);
    expect(controller.state.firstCorrectCount, 1);
    expect(controller.state.independentIds, {
      'mp_u1l1_review_1',
      'mp_u1l1_review_2',
    });
    expect(controller.state.independentSuccess, isFalse);
  });

  test(
    'fallback correction after spoken mismatch preserves first spoken failure',
    () {
      controller.dispose();
      controller = MotherPatternController(
        lesson: lesson,
        reviewExercises: lesson.patternLesson!.review.take(2).toList(),
      );
      controller.submit('wrong', modality: MotherPatternModality.spoken);
      controller.enableTypedFallback();
      expect(controller.state.checked, isFalse);
      expect(controller.state.currentTypedFallback, isTrue);
      expect(
        controller.submit(
          controller.state.current.answer,
          modality: MotherPatternModality.typedFallback,
        ),
        isTrue,
      );
      controller.next();
      finishMother(controller);
      expect(controller.state.firstCorrectCount, 1);
      expect(controller.state.firstSpokenCorrectCount, 1);
      expect(controller.state.firstTypedFallbackCorrectCount, 0);
      expect(controller.state.typedFallbackIds, {'mp_u1l1_review_1'});
      expect(controller.state.attempts.map((a) => a.modality), [
        MotherPatternModality.spoken,
        MotherPatternModality.typedFallback,
        MotherPatternModality.spoken,
      ]);
      expect(controller.state.attempts[1].first, isFalse);
      expect(controller.state.independentSuccess, isFalse);
    },
  );

  test(
    'typed fallback first success uses exact authored acceptance and never counts as spoken',
    () {
      controller.dispose();
      controller = MotherPatternController(
        lesson: lesson,
        reviewExercises: lesson.patternLesson!.review.take(2).toList(),
      );
      controller.enableTypedFallback();
      expect(
        controller.submit(
          "I'm Tom.",
          modality: MotherPatternModality.typedFallback,
        ),
        isTrue,
      );
      controller.next();
      controller.enableTypedFallback();
      controller.submit(
        controller.state.current.answer,
        modality: MotherPatternModality.typedFallback,
      );
      controller.next();
      expect(controller.state.independentSuccess, isTrue);
      expect(controller.state.firstSpokenCorrectCount, 0);
      expect(controller.state.firstTypedFallbackCorrectCount, 2);
    },
  );

  test('dialogue derives four scenario independent IDs from metadata', () {
    controller.dispose();
    controller = MotherPatternController(
      lesson: motherCourse().orderedLessons[3],
    );
    expect(controller.state.independentIds, {
      'mp_u1l4_e7',
      'mp_u1l4_e8',
      'mp_u1l4_e9',
      'mp_u1l4_e10',
    });
    finishMother(controller);
    expect(controller.state.independentSuccess, isTrue);
  });

  test(
    'independent modality counts exclude guided repeats and hinted first successes',
    () {
      for (var i = 0; i < 8; i++) {
        controller.submit(
          controller.state.current.answer,
          modality: modalityFor(controller.state.current),
        );
        controller.next();
      }
      controller.revealHint();
      finishMother(controller);
      expect(controller.state.firstSpokenCorrectCount, 4);
      expect(controller.state.independentSpokenCorrectCount, 1);
      expect(controller.state.independentTypedCorrectCount, 2);
      expect(controller.state.independentTypedFallbackCorrectCount, 0);
      expect(controller.state.independentCorrectCount, 3);
    },
  );

  test('immutable evidence and queue reject external changes', () {
    controller.submit(
      controller.state.current.answer,
      modality: MotherPatternModality.typed,
    );
    expect(() => controller.state.queue.clear(), throwsUnsupportedError);
    expect(
      () => controller.state.firstCorrectIds.clear(),
      throwsUnsupportedError,
    );
    expect(() => controller.state.attempts.clear(), throwsUnsupportedError);
    expect(
      () => controller.state.independentIds.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'invalid review count, unrelated exercises and dialogue review reject',
    () {
      expect(
        () => MotherPatternController(lesson: lesson, reviewExercises: []),
        throwsArgumentError,
      );
      expect(
        () => MotherPatternController(
          lesson: lesson,
          reviewExercises: [lesson.patternLesson!.review.first],
        ),
        throwsArgumentError,
      );
      expect(
        () => MotherPatternController(
          lesson: lesson,
          reviewExercises: lesson.exercises.take(2).toList(),
        ),
        throwsArgumentError,
      );
      expect(
        () => MotherPatternController(
          lesson: motherCourse().orderedLessons[3],
          reviewExercises: lesson.patternLesson!.review.take(2).toList(),
        ),
        throwsArgumentError,
      );
    },
  );
}
