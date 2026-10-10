import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/features/lesson/lesson_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const exercise = Exercise(
  id: 'e',
  type: ExerciseType.translateInput,
  prompt: '我想开户。',
  sentence: 'I would like to open an account.',
  options: [],
  answer: 'I would like to open an account.',
  acceptedAnswers: ['I want to open an account.'],
);

void main() {
  test(
    'translation alternatives preserve retry scoring and exact dictation',
    () {
      final c = LessonController(
        const Lesson(id: 'l', title: 'l', exercises: [exercise]),
      );
      addTearDown(c.dispose);
      expect(c.submit(' I WANT TO OPEN AN ACCOUNT! '), isTrue);
      expect(c.state.correctCount, 1);
      expect(exercise.accepts('I would like to close an account.'), isFalse);
      const dictation = Exercise(
        id: 'd',
        type: ExerciseType.dictation,
        prompt: '',
        sentence: 'I would like to open an account.',
        options: [],
        answer: 'I would like to open an account.',
        acceptedAnswers: ['I want to open an account.'],
      );
      expect(dictation.accepts('I want to open an account.'), isFalse);
      final legacy = Exercise.fromJson({
        'id': 'old',
        'type': 'translateInput',
        'prompt': '',
        'sentence': 'Hello.',
        'answer': 'Hello.',
      });
      expect(legacy.acceptedAnswers, isEmpty);
    },
  );

  group('local review schedule', () {
    late Directory temp;
    late DateTime now;
    late LearningStore store;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('learning_records');
      Hive.init(temp.path);
      await Hive.openBox<String>(LearningStore.boxName);
      now = DateTime.utc(2026, 10, 10);
      store = LearningStore(userKey: 'alice', clock: () => now);
    });
    tearDown(() async {
      await Hive.close();
      await temp.delete(recursive: true);
    });

    Future<void> record(
      bool correct, {
      String mode = 'lesson',
      bool first = true,
      bool skipped = false,
    }) => store.recordAnswer(
      courseId: 'zero',
      lessonId: 'l',
      exercise: exercise,
      correct: correct,
      first: first,
      elapsedMs: 1000,
      mode: mode,
      skipped: skipped,
    );

    test(
      'wrong answer schedules review; in-session correction cannot clear it',
      () async {
        await record(false);
        await record(true, first: false);
        expect(store.reviews['e']['stage'], 0);
        await record(true, mode: 'review');
        expect(store.reviews['e']['stage'], 1);
        expect(
          DateTime.parse(store.reviews['e']['due']),
          now.add(const Duration(days: 1)),
        );
        await record(true, mode: 'review', first: false);
        expect(store.reviews['e']['stage'], 1);
        await record(false, mode: 'review');
        await record(true, mode: 'review', first: false);
        expect(store.reviews['e']['stage'], 0);
      },
    );

    test(
      'accounts isolated; skipped items do not create mistakes; clear leaves no records',
      () async {
        await record(false, skipped: true);
        expect(store.reviews, isEmpty);
        await record(false);
        expect(LearningStore(userKey: 'bob').reviews, isEmpty);
        expect(store.exportJson(), isNot(contains('I want')));
        await store.clear();
        expect(store.events, isEmpty);
        expect(store.reviews, isEmpty);
      },
    );

    test(
      'review stages use 1, 3, 7 days and resolve after fourth success',
      () async {
        await record(false);
        for (final days in [1, 3, 7, 14]) {
          await record(true, mode: 'review');
          final due = DateTime.parse(store.reviews['e']['due']);
          expect(due, now.add(Duration(days: days)));
          now = due;
        }
        expect(store.reviews['e']['resolved'], isTrue);
      },
    );
  });
}
