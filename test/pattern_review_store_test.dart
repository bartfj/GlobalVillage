import 'dart:convert';
import 'dart:io';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/pattern_training.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'pattern_training_fixture.dart';

void main() {
  late Directory temp;
  late DateTime now;
  late LearningStore store;
  late PatternTraining training;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pattern_review');
    Hive.init(temp.path);
    await Hive.openBox<String>(LearningStore.boxName);
    now = DateTime.utc(2026, 11, 12, 10);
    store = LearningStore(userKey: 'alice', clock: () => now);
    training = PatternTraining.fromJson(patternJson());
  });
  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  Future<dynamic> save(
    String session, {
    bool review = false,
    bool success = true,
    int hints = 0,
    LearningStore? target,
    String courseId = 'beginner',
    PatternTraining? pattern,
    String lessonId = 'l1',
  }) {
    final dynamic receiver = target ?? store;
    return receiver.recordPatternSession(
      courseId: courseId,
      lessonId: lessonId,
      sessionId: session,
      training: pattern ?? training,
      review: review,
      independentSuccess: success,
      firstCorrect: success ? (review ? 2 : 6) : 1,
      totalCount: review ? 2 : 6,
      hints: hints,
    );
  }

  dynamic entry({
    String courseId = 'beginner',
    PatternTraining? pattern,
    LearningStore? target,
  }) {
    final dynamic receiver = target ?? store;
    return receiver.patternReview(courseId, pattern ?? training);
  }

  test(
    'first learning succeeds tomorrow; substitution hints do not change success',
    () async {
      final e = await save('learn', hints: 1);
      expect(e.due, now.add(const Duration(days: 1)));
      expect(e.stage, 0);
      expect(e.reviewCursor, 0);
      expect(e.firstCorrect, 6);
      expect(e.totalCount, 6);
      expect(e.hints, 1);
      expect(e.lessonId, 'l1');
    },
  );
  test('failed first learning schedules today', () async {
    expect((await save('learn', success: false)).due, now);
  });
  test(
    'learning again preserves advanced interval but failure resets today',
    () async {
      await save('learn');
      now = now.add(const Duration(days: 1));
      final reviewed = await save('r1', review: true);
      now = now.add(const Duration(hours: 1));
      final again = await save('learn-again');
      expect(again.due, reviewed.due);
      expect(again.stage, reviewed.stage);
      final failed = await save('learn-failed', success: false);
      expect(failed.due, now);
      expect(failed.stage, 0);
    },
  );
  test(
    'review intervals are 3 then 7 then 14 and remain capped at 14 days',
    () async {
      await save('learn');
      var stage = 0;
      for (final days in [3, 7, 14, 14, 14]) {
        now = entry().due;
        final e = await save('r${stage++}', review: true);
        expect(e.due, now.add(Duration(days: days)));
        expect(e.stage, stage.clamp(1, 3));
      }
    },
  );
  test('review failure and hints reset stage and due date', () async {
    await save('learn');
    await save('r1', review: true);
    final e = await save('r2', review: true, hints: 1);
    expect(e.stage, 0);
    expect(e.due, now);
    final next = await save('r3', review: true);
    expect(next.stage, 1);
    final failed = await save('r4', review: true, success: false);
    expect(failed.stage, 0);
    expect(failed.due, now);
  });
  test(
    'rotation reads are pure, advance two after review and wrap odd banks',
    () async {
      final dynamic receiver = store;
      List<Exercise> read() =>
          (receiver.patternReviewExercises('beginner', training) as List)
              .cast<Exercise>();
      expect(read().map((e) => e.id), ['mp_want_rev1', 'mp_want_rev2']);
      expect(read().map((e) => e.id), ['mp_want_rev1', 'mp_want_rev2']);
      await save('learn');
      expect(entry().reviewCursor, 0);
      await save('r1', review: true);
      expect(read().map((e) => e.id), ['mp_want_rev3', 'mp_want_rev4']);
      await save('r2', review: true, success: false);
      expect(read().map((e) => e.id), ['mp_want_rev5', 'mp_want_rev1']);
      expect(entry().reviewCursor, 4);
    },
  );
  test(
    'same session is idempotent across instances and after Hive restart',
    () async {
      await save('learn');
      final first = await save('review', review: true);
      final second = LearningStore(
        userKey: 'alice',
        clock: () => now.add(const Duration(days: 20)),
      );
      final duplicate = await save(
        'review',
        review: true,
        target: second,
        success: false,
      );
      expect(duplicate.due, first.due);
      expect(duplicate.stage, first.stage);
      expect(duplicate.reviewCursor, 2);
      expect(store.events, hasLength(2));
      await Hive.close();
      await Hive.openBox<String>(LearningStore.boxName);
      await save('review', review: true, target: second);
      expect(entry().reviewCursor, 2);
      expect(store.events, hasLength(2));
      expect(entry().firstCorrect, first.firstCorrect);
    },
  );
  test(
    'distinct overlapping instances cannot lose schedules or events',
    () async {
      final second = LearningStore(userKey: 'alice', clock: () => now);
      await save('learn');
      await Future.wait([
        save('a', review: true),
        save('b', review: true, target: second),
      ]);
      expect(entry().stage, 2);
      expect(entry().reviewCursor, 4);
      expect(store.events, hasLength(3));
      await Future.wait([
        save('same', review: true),
        save('same', review: true, target: second),
      ]);
      expect(entry().stage, 3);
      expect(entry().reviewCursor, 6);
      expect(store.events, hasLength(4));
    },
  );
  test('course, account, pattern and version isolate scheduling', () async {
    await save('learn');
    expect(entry(target: LearningStore(userKey: 'bob')), isNull);
    expect(entry(courseId: 'zero'), isNull);
    expect(
      entry(pattern: PatternTraining.fromJson(patternJson(version: 2))),
      isNull,
    );
    expect(
      entry(pattern: PatternTraining.fromJson(patternJson(id: 'mp_other'))),
      isNull,
    );
  });
  test(
    'due lessons filter completed pilots, order by due and cap at six',
    () async {
      final lessons = <Lesson>[];
      for (var i = 0; i < 9; i++) {
        final p = PatternTraining.fromJson(patternJson(id: 'mp_p$i'));
        lessons.add(
          Lesson(
            id: 'l$i',
            title: 'Pattern',
            exercises: [],
            patternTraining: p,
          ),
        );
        now = now.add(const Duration(hours: 1));
        await save('s$i', pattern: p, lessonId: 'l$i', success: false);
      }
      lessons.add(const Lesson(id: 'legacy', title: 'Legacy', exercises: []));
      final course = Course(
        id: 'beginner',
        title: 'Test',
        units: [
          Unit(id: 'u', title: 'Unit', description: '', lessons: lessons),
        ],
      );
      final dynamic receiver = store;
      final due =
          receiver.duePatternLessons(course, {
                'legacy',
                for (var i = 1; i < 9; i++) 'l$i',
              })
              as List;
      expect(due.map((dynamic l) => l.id), [
        'l1',
        'l2',
        'l3',
        'l4',
        'l5',
        'l6',
      ]);
      final other = Course(id: 'zero', title: 'Other', units: course.units);
      expect(receiver.duePatternLessons(other, {'l1'}), isEmpty);
    },
  );
  test('future pattern schedules are excluded until due', () async {
    await save('learn');
    final course = Course(
      id: 'beginner',
      title: '',
      units: [
        Unit(
          id: 'u',
          title: '',
          description: '',
          lessons: [
            Lesson(
              id: 'l1',
              title: '',
              exercises: [],
              patternTraining: training,
            ),
          ],
        ),
      ],
    );
    final dynamic receiver = store;
    expect(receiver.duePatternLessons(course, {'l1'}), isEmpty);
    now = entry().due;
    expect(receiver.duePatternLessons(course, {'l1'}), hasLength(1));
  });
  test(
    'next-day morning includes a pattern due later on that local date',
    () async {
      now = DateTime(2026, 11, 12, 15);
      await save('learn');
      final course = Course(
        id: 'beginner',
        title: '',
        units: [
          Unit(
            id: 'u',
            title: '',
            description: '',
            lessons: [
              Lesson(
                id: 'l1',
                title: '',
                exercises: [],
                patternTraining: training,
              ),
            ],
          ),
        ],
      );
      now = DateTime(2026, 11, 13, 8);
      expect(entry().due.isAfter(now), isTrue);
      final dynamic receiver = store;
      expect(receiver.duePatternLessons(course, {'l1'}), hasLength(1));
    },
  );
  test(
    'export includes patterns without answers; clear isolates account',
    () async {
      await save('learn');
      final bob = LearningStore(userKey: 'bob', clock: () => now);
      await save('learn', target: bob);
      final decoded = jsonDecode(store.exportJson()) as Map;
      expect(decoded['patternReviews'], isNotEmpty);
      expect(store.exportJson(), isNot(contains('I want tea')));
      await store.clear();
      expect(entry(), isNull);
      expect(store.events, isEmpty);
      expect(entry(target: bob), isNotNull);
      await save('learn'); // clearing removes the session ledger too
      expect(entry(), isNotNull);
    },
  );
  test('incomplete review cannot mutate schedule or cursor', () async {
    final dynamic receiver = store;
    await expectLater(
      receiver.recordPatternSession(
        courseId: 'beginner',
        lessonId: 'l1',
        sessionId: 'incomplete',
        training: training,
        review: true,
        independentSuccess: true,
        firstCorrect: 1,
        totalCount: 1,
        hints: 0,
      ),
      throwsArgumentError,
    );
    expect(entry(), isNull);
    expect(store.events, isEmpty);
  });
}
