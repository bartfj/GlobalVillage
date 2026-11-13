import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/data/sources/mother_pattern_store.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'mother_pattern_controller_test.dart'
    show motherCourse, finishMother, modalityFor;

class FailingTelemetryStore extends LearningStore {
  bool fail = true;
  final bool afterAppend;
  FailingTelemetryStore({
    required super.userKey,
    required super.clock,
    this.afterAppend = false,
  });
  @override
  Future<T> serializeSession<T>(
    Future<T> Function(Future<void> Function(Map<String, dynamic>)) action,
  ) => super.serializeSession(
    (append) => action((event) async {
      if (afterAppend) await append(event);
      if (fail) {
        fail = false;
        throw const FileSystemException('telemetry write unavailable');
      }
      if (!afterAppend) await append(event);
    }),
  );
}

class PausingTelemetryStore extends LearningStore {
  final reached = Completer<void>();
  final release = Completer<void>();
  PausingTelemetryStore({required super.userKey, required super.clock});
  @override
  Future<T> serializeSession<T>(
    Future<T> Function(Future<void> Function(Map<String, dynamic>)) action,
  ) => super.serializeSession(
    (append) => action((event) async {
      reached.complete();
      await release.future;
      await append(event);
    }),
  );
}

void main() {
  late Directory temp;
  late DateTime now;
  late Course course;
  late Lesson lesson;
  late LearningStore learning;
  late MotherPatternStore store;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mother_pattern_review');
    Hive.init(temp.path);
    await Hive.openBox<String>(LearningStore.boxName);
    now = DateTime.utc(2026, 11, 13, 10);
    course = motherCourse();
    lesson = course.orderedLessons.first;
    learning = LearningStore(userKey: 'alice', clock: () => now);
    store = MotherPatternStore(
      userKey: 'alice',
      clock: () => now,
      learningStore: learning,
    );
  });
  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  MotherPatternState completed({
    Lesson? target,
    MotherPatternReviewSnapshot? snapshot,
    bool fail = false,
    bool hint = false,
    bool fallback = false,
  }) {
    final controller = MotherPatternController(
      lesson: target ?? lesson,
      reviewExercises: snapshot?.exercises,
    );
    if (fail || hint) {
      if (snapshot == null) {
        for (var i = 0; i < 6; i++) {
          controller.submit(
            controller.state.current.answer,
            modality: modalityFor(controller.state.current),
          );
          controller.next();
        }
      }
      if (hint) controller.revealHint();
      if (fail) {
        controller.submit(
          'wrong',
          modality: modalityFor(controller.state.current),
        );
        if (fallback &&
            controller.state.current.type == ExerciseType.speaking) {
          controller.enableTypedFallback();
          controller.submit(
            controller.state.current.answer,
            modality: MotherPatternModality.typedFallback,
          );
        }
        controller.next();
      }
    }
    finishMother(controller);
    final state = controller.state;
    controller.dispose();
    return state;
  }

  Future<MotherPatternSessionResult> save(
    String session, {
    Lesson? target,
    MotherPatternReviewSnapshot? snapshot,
    bool fail = false,
    bool hint = false,
    bool fallback = false,
    MotherPatternStore? receiver,
    String courseId = 'motherPattern',
  }) => (receiver ?? store).recordSession(
    courseId: courseId,
    lesson: target ?? lesson,
    sessionId: session,
    state: completed(
      target: target,
      snapshot: snapshot,
      fail: fail,
      hint: hint,
      fallback: fallback,
    ),
    reviewSnapshot: snapshot,
  );

  MotherPatternReviewEntry? read() =>
      store.reviewEntry(course.id, lesson.patternLesson!);

  test(
    'initial full unaided training is tomorrow and records answer-free evidence',
    () async {
      final result = await save('learn');
      expect(result.entry!.due, now.add(const Duration(days: 1)));
      expect(result.entry!.stage, 0);
      expect(result.entry!.reviewCursor, 0);
      expect(result.entry!.totalCount, 10);
      expect(result.entry!.firstCorrect, 10);
      expect(result.entry!.hints, 0);
      expect(result.reason, MotherPatternSaveReason.learning);
      expect(learning.events, hasLength(1));
      final event = learning.events.single as Map;
      expect(event['independentSpokenCorrect'], 2);
      expect(event['independentTypedCorrect'], 2);
      expect(event['independentTypedFallbackCorrect'], 0);
      expect(event['attempts'], hasLength(10));
      expect(learning.exportJson(), isNot(contains('I am Tom')));
      expect(learning.exportJson(), isNot(contains('transcript')));
    },
  );

  test(
    'first independent error or hint is due today despite same-session correction',
    () async {
      final failure = await save('fail', fail: true);
      expect(failure.entry!.due, now);
      expect(failure.entry!.firstCorrect, 9);
      expect(failure.entry!.stage, 0);
      await learning.clear();
      final hinted = await save('hint', hint: true);
      expect(hinted.entry!.due, now);
      expect(hinted.entry!.firstCorrect, 10);
      expect(hinted.entry!.hints, 1);
      expect(learning.events.single['hintedIds'], ['mp_u1l1_e7']);
    },
  );

  test(
    'due formal review progresses three seven fourteen days and capped at fourteen',
    () async {
      await save('learn');
      var count = 0;
      for (final days in [3, 7, 14, 14]) {
        now = read()!.due;
        final snapshot = store.reviewSnapshot(course.id, lesson);
        expect(snapshot.dueEligible, isTrue);
        final result = await save('review${count++}', snapshot: snapshot);
        expect(result.entry!.due, now.add(Duration(days: days)));
        expect(result.entry!.stage, count.clamp(1, 3));
        expect(result.entry!.reviewCursor, count * 2);
        expect(result.scheduleAdvanced, isTrue);
        expect(result.reason, MotherPatternSaveReason.dueReview);
      }
      expect(learning.events, hasLength(5));
    },
  );

  test(
    'failed or hinted due review resets today while a full legitimate round rotates',
    () async {
      await save('learn');
      now = read()!.due;
      await save('r1', snapshot: store.reviewSnapshot(course.id, lesson));
      now = read()!.due;
      final failure = await save(
        'r2',
        snapshot: store.reviewSnapshot(course.id, lesson),
        fail: true,
        fallback: true,
      );
      expect(failure.entry!.stage, 0);
      expect(failure.entry!.due, now);
      expect(failure.entry!.reviewCursor, 4);
      final event = learning.events.last as Map;
      expect(event['typedFallbackIds'], ['mp_u1l1_review_3']);
      expect(event['independentSpokenCorrect'], 1);
      expect(event['independentTypedFallbackCorrect'], 0);
      expect(event['attempts'], hasLength(3));
      final hinted = await save(
        'r3',
        snapshot: store.reviewSnapshot(course.id, lesson),
        hint: true,
      );
      expect(hinted.entry!.stage, 0);
      expect(hinted.entry!.due, now);
      expect(hinted.entry!.reviewCursor, 6);
    },
  );

  test(
    'rotation read is pure and future practice never advances even once its date becomes due',
    () async {
      await save('learn');
      final snapshot = store.reviewSnapshot(course.id, lesson);
      expect(snapshot.exercises.map((e) => e.id), [
        'mp_u1l1_review_1',
        'mp_u1l1_review_2',
      ]);
      expect(snapshot.dueEligible, isFalse);
      expect(store.reviewSnapshot(course.id, lesson).reviewCursor, 0);
      now = read()!.due;
      final practice = await save('early-open', snapshot: snapshot);
      expect(practice.reason, MotherPatternSaveReason.practice);
      expect(practice.scheduleAdvanced, isFalse);
      expect(read()!.stage, 0);
      expect(read()!.reviewCursor, 0);
      await save('due', snapshot: store.reviewSnapshot(course.id, lesson));
      expect(
        store.reviewSnapshot(course.id, lesson).exercises.map((e) => e.id),
        ['mp_u1l1_review_3', 'mp_u1l1_review_4'],
      );
    },
  );

  test(
    'untrained review practice cannot create completed-training eligibility',
    () async {
      expect(store.dueLessons(course), isEmpty);
      await save(
        'untrained-practice',
        snapshot: store.reviewSnapshot(course.id, lesson),
      );
      expect(read(), isNull);
      expect(store.dueLessons(course), isEmpty);
      expect(learning.events, hasLength(1));
      await save('learn');
      now = read()!.due;
      expect(store.dueLessons(course).map((l) => l.id), ['mp_u1l1']);
    },
  );

  test(
    'only one concurrent save with the same due snapshot advances; retry returns original result',
    () async {
      await save('learn');
      now = read()!.due;
      final snapshot = store.reviewSnapshot(course.id, lesson);
      final second = MotherPatternStore(userKey: 'alice', clock: () => now);
      final results = await Future.wait([
        save('a', snapshot: snapshot),
        save('b', snapshot: snapshot, receiver: second),
      ]);
      expect(results.where((r) => r.scheduleAdvanced), hasLength(1));
      expect(
        results.where((r) => r.reason == MotherPatternSaveReason.staleReview),
        hasLength(1),
      );
      expect(read()!.stage, 1);
      expect(read()!.reviewCursor, 2);
      final retry = await save(
        'a',
        snapshot: snapshot,
        receiver: second,
        fail: true,
      );
      expect(retry.reason, MotherPatternSaveReason.dueReview);
      expect(retry.entry!.firstCorrect, 2);
      expect(retry.entry!.reviewCursor, 2);
      expect(learning.events, hasLength(3));
      now = read()!.due;
      await save('next', snapshot: store.reviewSnapshot(course.id, lesson));
      await Hive.close();
      await Hive.openBox<String>(LearningStore.boxName);
      final reopened = await save('a', snapshot: snapshot, receiver: second);
      expect(reopened.entry!.stage, 1);
      expect(reopened.entry!.reviewCursor, 2);
      expect(read()!.stage, 2);
      expect(read()!.reviewCursor, 4);
      expect(learning.events, hasLength(4));
    },
  );

  test(
    'telemetry failure after schedule write retries without double advancement',
    () async {
      await save('learn');
      now = read()!.due;
      final snapshot = store.reviewSnapshot(course.id, lesson);
      final failingLearning = FailingTelemetryStore(
        userKey: 'alice',
        clock: () => now,
      );
      final failingStore = MotherPatternStore(
        userKey: 'alice',
        clock: () => now,
        learningStore: failingLearning,
      );
      await expectLater(
        save('r1', snapshot: snapshot, receiver: failingStore),
        throwsA(isA<FileSystemException>()),
      );
      expect(read()!.stage, 1);
      expect(read()!.reviewCursor, 2);
      final retry = await save(
        'r1',
        snapshot: snapshot,
        receiver: failingStore,
      );
      expect(retry.entry!.stage, 1);
      expect(retry.entry!.reviewCursor, 2);
      expect(learning.events, hasLength(2));
    },
  );

  test(
    'failed Hive write leaves no result and succeeds after reopen',
    () async {
      final state = completed();
      await Hive.close();
      await expectLater(
        store.recordSession(
          courseId: course.id,
          lesson: lesson,
          sessionId: 'learn',
          state: state,
        ),
        throwsA(isA<HiveError>()),
      );
      await Hive.openBox<String>(LearningStore.boxName);
      expect(read(), isNull);
      await store.recordSession(
        courseId: course.id,
        lesson: lesson,
        sessionId: 'learn',
        state: state,
      );
      expect(read()!.due, now.add(const Duration(days: 1)));
      expect(learning.events, hasLength(1));
    },
  );

  test(
    'failure after event append retries without another event or advancement',
    () async {
      await save('learn');
      now = read()!.due;
      final snapshot = store.reviewSnapshot(course.id, lesson);
      final failingLearning = FailingTelemetryStore(
        userKey: 'alice',
        clock: () => now,
        afterAppend: true,
      );
      final failingStore = MotherPatternStore(
        userKey: 'alice',
        clock: () => now,
        learningStore: failingLearning,
      );
      await expectLater(
        save('r1', snapshot: snapshot, receiver: failingStore),
        throwsA(isA<FileSystemException>()),
      );
      expect(learning.events, hasLength(2));
      expect(read()!.reviewCursor, 2);
      await save('r1', snapshot: snapshot, receiver: failingStore);
      expect(learning.events, hasLength(2));
      expect(read()!.reviewCursor, 2);
    },
  );

  test(
    'persisted summary after spoken mismatch retains hints and fallback evidence across restart',
    () async {
      await save('learn');
      now = read()!.due;
      final snapshot = store.reviewSnapshot(course.id, lesson);
      await save(
        'failed-review',
        snapshot: snapshot,
        fail: true,
        hint: true,
        fallback: true,
      );
      await Hive.close();
      await Hive.openBox<String>(LearningStore.boxName);
      final reopened = MotherPatternStore(userKey: 'alice', clock: () => now);
      final summary = reopened.latestSummary(course.id, lesson.patternLesson!);
      expect(summary, isNotNull);
      expect(summary!.sessionId, 'failed-review');
      expect(summary.isReview, isTrue);
      expect(summary.saveReason, MotherPatternSaveReason.dueReview);
      expect(summary.independentTotal, 2);
      expect(summary.independentCorrect, 1);
      expect(summary.independentSpokenCorrect, 1);
      expect(summary.independentTypedCorrect, 0);
      expect(summary.independentTypedFallbackCorrect, 0);
      expect(summary.firstCorrect, 1);
      expect(summary.totalCount, 2);
      expect(summary.hints, 1);
      expect(summary.hintedIds, ['mp_u1l1_review_1']);
      expect(summary.typedFallbackIds, ['mp_u1l1_review_1']);
      expect(summary.fallbackUsed, isTrue);
      expect(() => summary.hintedIds.clear(), throwsUnsupportedError);
      expect(() => summary.typedFallbackIds.clear(), throwsUnsupportedError);
      await save('learn', receiver: reopened);
      expect(
        reopened.latestSummary(course.id, lesson.patternLesson!)!.sessionId,
        'failed-review',
      );
    },
  );

  test(
    'persisted first typed fallback successes never become spoken success after restart',
    () async {
      await save('learn');
      now = read()!.due;
      final snapshot = store.reviewSnapshot(course.id, lesson);
      final controller = MotherPatternController(
        lesson: lesson,
        reviewExercises: snapshot.exercises,
      );
      for (var i = 0; i < 2; i++) {
        controller.enableTypedFallback();
        controller.submit(
          controller.state.current.answer,
          modality: MotherPatternModality.typedFallback,
        );
        controller.next();
      }
      final result = await store.recordSession(
        courseId: course.id,
        lesson: lesson,
        sessionId: 'typed-review',
        state: controller.state,
        reviewSnapshot: snapshot,
      );
      controller.dispose();
      expect(result.scheduleAdvanced, isTrue);
      await Hive.close();
      await Hive.openBox<String>(LearningStore.boxName);
      final summary = MotherPatternStore(
        userKey: 'alice',
      ).latestSummary(course.id, lesson.patternLesson!);
      expect(summary, isNotNull);
      expect(summary!.independentTotal, 2);
      expect(summary.independentCorrect, 2);
      expect(summary.independentSpokenCorrect, 0);
      expect(summary.independentTypedCorrect, 0);
      expect(summary.independentTypedFallbackCorrect, 2);
      expect(summary.fallbackUsed, isTrue);
    },
  );

  test(
    'overlapping different-pattern saves retain both complete records and events',
    () async {
      await Future.wait([
        save('first'),
        save(
          'second',
          target: course.orderedLessons[1],
          receiver: MotherPatternStore(userKey: 'alice', clock: () => now),
        ),
      ]);
      expect(learning.motherPatternReviews, hasLength(2));
      expect(learning.events, hasLength(2));
      expect(
        store
            .reviewEntry(course.id, course.orderedLessons[1].patternLesson!)!
            .totalCount,
        10,
      );
    },
  );

  test(
    'incomplete or unrelated state and snapshot cannot mutate records',
    () async {
      final controller = MotherPatternController(lesson: lesson);
      await expectLater(
        store.recordSession(
          courseId: course.id,
          lesson: lesson,
          sessionId: 'incomplete',
          state: controller.state,
        ),
        throwsArgumentError,
      );
      controller.dispose();
      await expectLater(
        store.recordSession(
          courseId: course.id,
          lesson: lesson,
          sessionId: 'wrong-state',
          state: completed(target: course.orderedLessons[1]),
        ),
        throwsArgumentError,
      );
      final snapshot = store.reviewSnapshot(course.id, lesson);
      await expectLater(
        store.recordSession(
          courseId: course.id,
          lesson: lesson,
          sessionId: 'missing-snapshot',
          state: completed(snapshot: snapshot),
        ),
        throwsArgumentError,
      );
      final bobSnapshot = MotherPatternStore(
        userKey: 'bob',
        clock: () => now,
      ).reviewSnapshot(course.id, lesson);
      await expectLater(
        store.recordSession(
          courseId: course.id,
          lesson: lesson,
          sessionId: 'wrong-account',
          state: completed(snapshot: snapshot),
          reviewSnapshot: bobSnapshot,
        ),
        throwsArgumentError,
      );
      expect(read(), isNull);
      expect(learning.events, isEmpty);
    },
  );

  test(
    'dialogue completion logs only and never schedules referenced patterns',
    () async {
      final dialogue = course.orderedLessons[3];
      final result = await save('dialogue', target: dialogue);
      expect(result.entry, isNull);
      expect(result.reason, MotherPatternSaveReason.dialogue);
      expect(result.scheduleAdvanced, isFalse);
      expect(store.dueLessons(course), isEmpty);
      expect(learning.events, hasLength(1));
      expect(learning.events.single['patternKind'], 'dialogue');
      for (final target in course.orderedLessons.take(4)) {
        expect(store.reviewEntry(course.id, target.patternLesson!), isNull);
      }
      expect(
        () => store.reviewSnapshot(course.id, dialogue),
        throwsArgumentError,
      );
    },
  );

  test(
    'eligibility uses saved new training only, earliest due six and excludes legacy',
    () async {
      final patterns = course.orderedLessons
          .where((l) => l.patternLesson!.review.isNotEmpty)
          .toList();
      for (var i = 0; i < 9; i++) {
        now = now.add(const Duration(hours: 1));
        await save('learn$i', target: patterns[i], fail: true);
      }
      expect(store.dueLessons(course).map((l) => l.id), [
        'mp_u1l1',
        'mp_u1l2',
        'mp_u1l3',
        'mp_u2l1',
        'mp_u2l2',
        'mp_u2l3',
      ]);
      final other = Course(id: 'other', title: '', units: course.units);
      expect(store.dueLessons(other), isEmpty);
      await learning.clear();
      await Hive.box<String>(LearningStore.boxName).put(
        'alice|patternReviews',
        jsonEncode({
          'old': {'due': now.toIso8601String()},
        }),
      );
      expect(store.dueLessons(course), isEmpty);
    },
  );

  test(
    'next-day local morning includes later-today due time and save uses same calendar eligibility',
    () async {
      now = DateTime(2026, 11, 13, 15);
      await save('learn');
      now = DateTime(2026, 11, 14, 8);
      expect(read()!.due.isAfter(now), isTrue);
      expect(store.dueLessons(course), hasLength(1));
      final snapshot = store.reviewSnapshot(course.id, lesson);
      expect(snapshot.dueEligible, isTrue);
      final result = await save('morning', snapshot: snapshot);
      expect(result.entry!.due.toLocal(), DateTime(2026, 11, 17, 8));
      expect(result.scheduleAdvanced, isTrue);
    },
  );

  test(
    'account course pattern version separate, export and clear preserve other accounts and old records until explicit clear',
    () async {
      await Hive.box<String>(
        LearningStore.boxName,
      ).put('alice|patternReviews', '{"old":{"stage":2}}');
      await save('learn');
      expect(learning.patternReviews, {
        'old': {'stage': 2},
      });
      final bob = MotherPatternStore(userKey: 'bob', clock: () => now);
      await save('bob-learn', receiver: bob);
      expect(bob.reviewEntry(course.id, lesson.patternLesson!), isNotNull);
      expect(store.reviewEntry('different', lesson.patternLesson!), isNull);
      expect(
        store.reviewEntry(course.id, course.orderedLessons[1].patternLesson!),
        isNull,
      );
      final packJson =
          jsonDecode(
                File(
                  'assets/courses/course_mother_pattern.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      packJson['units'][0]['lessons'][0]['patternLesson']['version'] = 2;
      final v2 = Course.fromJson(packJson).orderedLessons.first;
      expect(store.reviewEntry(course.id, v2.patternLesson!), isNull);
      await save('v2', target: v2);
      final exported = jsonDecode(learning.exportJson()) as Map;
      expect(exported['motherPatternReviews'], hasLength(2));
      expect(exported['patternReviews'], {
        'old': {'stage': 2},
      });
      await learning.clear();
      expect(read(), isNull);
      expect(learning.events, isEmpty);
      expect(learning.patternReviews, isEmpty);
      expect(bob.reviewEntry(course.id, lesson.patternLesson!), isNotNull);
      await save('learn');
      expect(read(), isNotNull);
    },
  );

  test(
    'learning again preserves interval on success and invalidates open review snapshot on failure',
    () async {
      await save('learn');
      now = read()!.due;
      await save('r1', snapshot: store.reviewSnapshot(course.id, lesson));
      final advanced = read()!;
      await save('learn-again');
      expect(read()!.due, advanced.due);
      expect(read()!.stage, 1);
      now = read()!.due;
      final snapshot = store.reviewSnapshot(course.id, lesson);
      await save('learn-failed', fail: true);
      expect(read()!.stage, 0);
      expect(read()!.due, now);
      final stale = await save('stale', snapshot: snapshot);
      expect(stale.reason, MotherPatternSaveReason.staleReview);
      expect(read()!.stage, 0);
      expect(read()!.reviewCursor, 2);
    },
  );

  test('durable telemetry dedup survives bounded event eviction', () async {
    await save('learn');
    final event = learning.events.single;
    await Hive.box<String>(LearningStore.boxName).put(
      'alice|events',
      jsonEncode([
        event,
        for (var i = 0; i < 1999; i++) {'kind': 'filler', 'number': i},
      ]),
    );
    await learning.log({'kind': 'newest'});
    expect(learning.events, hasLength(2000));
    expect(
      learning.events.where((e) => e['kind'] == 'motherPatternSession'),
      isEmpty,
    );
    await save('learn');
    expect(
      learning.events.where((e) => e['kind'] == 'motherPatternSession'),
      isEmpty,
    );
    expect(read()!.revision, 1);
  });

  test(
    'cleared and recreated schedule never legitimizes the old identical revision snapshot',
    () async {
      await save('learn', fail: true);
      final snapshot = store.reviewSnapshot(course.id, lesson);
      expect(snapshot.dueEligible, isTrue);
      await learning.clear();
      await save(
        'learn',
        fail: true,
      ); // same clock, IDs, cursor and numeric revision
      final stale = await save('old-review', snapshot: snapshot);
      expect(stale.reason, MotherPatternSaveReason.staleReview);
      expect(stale.scheduleAdvanced, isFalse);
      expect(read()!.stage, 0);
      expect(read()!.reviewCursor, 0);
    },
  );

  test(
    'partial new training summary cannot establish due eligibility',
    () async {
      await save('learn', fail: true);
      final records = learning.motherPatternReviews;
      final record = records.values.single as Map;
      record['completedTraining'] = {
        'lessonId': lesson.id,
        'totalCount': 10,
        'review': false,
      };
      await Hive.box<String>(
        LearningStore.boxName,
      ).put('alice|motherPatternReviews', jsonEncode(records));
      expect(store.dueLessons(course), isEmpty);
      expect(store.reviewSnapshot(course.id, lesson).dueEligible, isFalse);
    },
  );

  test(
    'clear from another instance waits for complete schedule and telemetry then removes both',
    () async {
      final pausing = PausingTelemetryStore(userKey: 'alice', clock: () => now);
      final savingStore = MotherPatternStore(
        userKey: 'alice',
        clock: () => now,
        learningStore: pausing,
      );
      final saving = save('learn', receiver: savingStore);
      await pausing.reached.future;
      final clearing = LearningStore(userKey: 'alice').clear();
      pausing.release.complete();
      await Future.wait([saving, clearing]);
      expect(read(), isNull);
      expect(learning.events, isEmpty);
      expect(learning.motherPatternReviews, isEmpty);
    },
  );
}
