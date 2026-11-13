import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';

import '../../features/mother_pattern/mother_pattern_controller.dart';
import '../models/course.dart';
import '../models/pattern_lesson.dart';
import 'learning_store.dart';

enum MotherPatternSaveReason {
  learning,
  dueReview,
  practice,
  staleReview,
  dialogue,
}

class MotherPatternReviewEntry {
  final String courseId;
  final String lessonId;
  final String patternId;
  final int patternVersion;
  final DateTime due;
  final int stage;
  final int reviewCursor;
  final int revision;
  final String revisionToken;
  final int firstCorrect;
  final int totalCount;
  final int hints;

  const MotherPatternReviewEntry({
    required this.courseId,
    required this.lessonId,
    required this.patternId,
    required this.patternVersion,
    required this.due,
    required this.stage,
    required this.reviewCursor,
    required this.revision,
    required this.revisionToken,
    required this.firstCorrect,
    required this.totalCount,
    required this.hints,
  });

  factory MotherPatternReviewEntry.fromJson(Map<String, dynamic> json) =>
      MotherPatternReviewEntry(
        courseId: json['courseId'] as String,
        lessonId: json['lessonId'] as String,
        patternId: json['patternId'] as String,
        patternVersion: json['patternVersion'] as int,
        due: DateTime.parse(json['due'] as String),
        stage: json['stage'] as int,
        reviewCursor: json['reviewCursor'] as int,
        revision: json['revision'] as int,
        revisionToken: json['revisionToken'] as String,
        firstCorrect: json['firstCorrect'] as int,
        totalCount: json['totalCount'] as int,
        hints: json['hints'] as int,
      );
  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'lessonId': lessonId,
    'patternId': patternId,
    'patternVersion': patternVersion,
    'due': due.toUtc().toIso8601String(),
    'stage': stage,
    'reviewCursor': reviewCursor,
    'revision': revision,
    'revisionToken': revisionToken,
    'firstCorrect': firstCorrect,
    'totalCount': totalCount,
    'hints': hints,
  };
}

class MotherPatternReviewSnapshot {
  final String userKey;
  final String courseId;
  final String lessonId;
  final String patternId;
  final int patternVersion;
  final List<Exercise> exercises;
  final bool dueEligible;
  final int revision;
  final String? revisionToken;
  final int reviewCursor;
  final DateTime? due;

  const MotherPatternReviewSnapshot._({
    required this.userKey,
    required this.courseId,
    required this.lessonId,
    required this.patternId,
    required this.patternVersion,
    required this.exercises,
    required this.dueEligible,
    required this.revision,
    required this.revisionToken,
    required this.reviewCursor,
    required this.due,
  });
}

class MotherPatternSessionResult {
  final MotherPatternReviewEntry? entry;
  final bool scheduleAdvanced;
  final MotherPatternSaveReason reason;
  const MotherPatternSessionResult({
    required this.entry,
    required this.scheduleAdvanced,
    required this.reason,
  });
  factory MotherPatternSessionResult.fromJson(Map<String, dynamic> json) =>
      MotherPatternSessionResult(
        entry: json['entry'] == null
            ? null
            : MotherPatternReviewEntry.fromJson(
                json['entry'] as Map<String, dynamic>,
              ),
        scheduleAdvanced: json['scheduleAdvanced'] as bool,
        reason: MotherPatternSaveReason.values.byName(json['reason'] as String),
      );
  Map<String, dynamic> toJson() => {
    'entry': entry?.toJson(),
    'scheduleAdvanced': scheduleAdvanced,
    'reason': reason.name,
  };
}

/// Answer-free performance for the latest completed session, including practice.
class MotherPatternSessionSummary {
  final String sessionId;
  final bool isReview;
  final MotherPatternSaveReason saveReason;
  final DateTime completedAt;
  final int firstCorrect;
  final int totalCount;
  final int hints;
  final List<String> hintedIds;
  final List<String> typedFallbackIds;
  final int independentTotal;
  final int independentCorrect;
  final int independentSpokenCorrect;
  final int independentTypedCorrect;
  final int independentTypedFallbackCorrect;

  const MotherPatternSessionSummary._({
    required this.sessionId,
    required this.isReview,
    required this.saveReason,
    required this.completedAt,
    required this.firstCorrect,
    required this.totalCount,
    required this.hints,
    required this.hintedIds,
    required this.typedFallbackIds,
    required this.independentTotal,
    required this.independentCorrect,
    required this.independentSpokenCorrect,
    required this.independentTypedCorrect,
    required this.independentTypedFallbackCorrect,
  });
  factory MotherPatternSessionSummary._fromEvent(Map<String, dynamic> event) =>
      MotherPatternSessionSummary._(
        sessionId: event['sessionId'] as String,
        isReview: event['review'] as bool,
        saveReason: MotherPatternSaveReason.values.byName(
          event['saveReason'] as String,
        ),
        completedAt: DateTime.parse(event['completedAt'] as String),
        firstCorrect: event['firstCorrect'] as int,
        totalCount: event['totalCount'] as int,
        hints: event['hints'] as int,
        hintedIds: List.unmodifiable(
          (event['hintedIds'] as List).cast<String>(),
        ),
        typedFallbackIds: List.unmodifiable(
          (event['typedFallbackIds'] as List).cast<String>(),
        ),
        independentTotal: (event['independentIds'] as List).length,
        independentCorrect: event['independentCorrect'] as int,
        independentSpokenCorrect: event['independentSpokenCorrect'] as int,
        independentTypedCorrect: event['independentTypedCorrect'] as int,
        independentTypedFallbackCorrect:
            event['independentTypedFallbackCorrect'] as int,
      );
  bool get fallbackUsed => typedFallbackIds.isNotEmpty;
}

/// Completed new-course sessions and due-only spaced reviews; answers stay in memory.
class MotherPatternStore {
  static final _random = Random.secure();
  final String userKey;
  final DateTime Function() clock;
  final LearningStore learningStore;

  MotherPatternStore({
    required this.userKey,
    DateTime Function()? clock,
    LearningStore? learningStore,
  }) : clock = clock ?? DateTime.now,
       learningStore =
           learningStore ?? LearningStore(userKey: userKey, clock: clock) {
    if (userKey.trim().isEmpty || this.learningStore.userKey != userKey) {
      throw ArgumentError('A store must capture one matching nonempty account');
    }
  }

  Box<String> get _box => Hive.box<String>(LearningStore.boxName);
  String get _storageKey => '$userKey|motherPatternReviews';
  Map<String, dynamic> get _records => learningStore.motherPatternReviews;
  String _patternKey(String courseId, PatternLesson pattern) =>
      jsonEncode([courseId, pattern.id, pattern.version]);
  MotherPatternSessionSummary? latestSummary(
    String courseId,
    PatternLesson pattern,
  ) {
    final record =
        _records[_patternKey(courseId, pattern)] as Map<String, dynamic>?;
    final latestId = record?['latestSessionId'] as String?;
    if (latestId == null) return null;
    final session =
        (record!['sessions'] as Map<String, dynamic>)[latestId]
            as Map<String, dynamic>;
    return MotherPatternSessionSummary._fromEvent(
      session['event'] as Map<String, dynamic>,
    );
  }

  MotherPatternReviewEntry? reviewEntry(
    String courseId,
    PatternLesson pattern,
  ) {
    final raw =
        _records[_patternKey(courseId, pattern)] as Map<String, dynamic>?;
    return raw?['entry'] == null
        ? null
        : MotherPatternReviewEntry.fromJson(
            raw!['entry'] as Map<String, dynamic>,
          );
  }

  bool _dueToday(DateTime due, DateTime now) {
    final local = now.toLocal();
    return due.toLocal().isBefore(
      DateTime(local.year, local.month, local.day + 1),
    );
  }

  MotherPatternReviewEntry? _entry(Map<String, dynamic>? record) =>
      record?['entry'] == null
      ? null
      : MotherPatternReviewEntry.fromJson(
          record!['entry'] as Map<String, dynamic>,
        );

  bool _trained(Map<String, dynamic>? record, Lesson lesson) {
    final summary = record?['completedTraining'] as Map<String, dynamic>?;
    final pattern = lesson.patternLesson!;
    if (summary == null ||
        summary['lessonId'] != lesson.id ||
        summary['patternId'] != pattern.id ||
        summary['patternVersion'] != pattern.version ||
        summary['totalCount'] != 10 ||
        summary['review'] != false ||
        summary['independentIds'] is! List ||
        summary['attempts'] is! List) {
      return false;
    }
    final independent = (summary['independentIds'] as List)
        .whereType<String>()
        .toList();
    if (!_sameIds(independent, pattern.independentExerciseIds)) return false;
    final first = (summary['attempts'] as List)
        .whereType<Map>()
        .where((attempt) => attempt['first'] == true)
        .toList();
    return first.length == 10 &&
        lesson.exercises.every(
          (exercise) =>
              first
                  .where((attempt) => attempt['exerciseId'] == exercise.id)
                  .length ==
              1,
        );
  }

  List<Lesson> dueLessons(Course course) {
    final records = _records;
    final now = clock();
    final lessons = course.orderedLessons;
    final candidates = <(Lesson, DateTime, int)>[];
    for (var index = 0; index < lessons.length; index++) {
      final lesson = lessons[index];
      final pattern = lesson.patternLesson;
      if (pattern == null || pattern.kind != PatternLessonKind.pattern) {
        continue;
      }
      final record =
          records[_patternKey(course.id, pattern)] as Map<String, dynamic>?;
      final entry = _entry(record);
      if (_trained(record, lesson) &&
          entry != null &&
          _dueToday(entry.due, now)) {
        candidates.add((lesson, entry.due, index));
      }
    }
    candidates.sort((a, b) {
      final due = a.$2.compareTo(b.$2);
      return due != 0 ? due : a.$3.compareTo(b.$3);
    });
    return List.unmodifiable(
      candidates.take(6).map((candidate) => candidate.$1),
    );
  }

  MotherPatternReviewSnapshot reviewSnapshot(String courseId, Lesson lesson) {
    final pattern = lesson.patternLesson;
    if (courseId.trim().isEmpty ||
        pattern == null ||
        pattern.kind != PatternLessonKind.pattern ||
        pattern.review.length < 2) {
      throw ArgumentError(
        'A review snapshot requires a pattern lesson and course',
      );
    }
    pattern.validateExercises(lesson.exercises);
    final record =
        _records[_patternKey(courseId, pattern)] as Map<String, dynamic>?;
    final entry = _entry(record);
    final cursor = entry?.reviewCursor ?? 0;
    return MotherPatternReviewSnapshot._(
      userKey: userKey,
      courseId: courseId,
      lessonId: lesson.id,
      patternId: pattern.id,
      patternVersion: pattern.version,
      exercises: List.unmodifiable([
        for (var i = 0; i < 2; i++)
          pattern.review[(cursor + i) % pattern.review.length],
      ]),
      dueEligible:
          _trained(record, lesson) &&
          entry != null &&
          _dueToday(entry.due, clock()),
      revision: entry?.revision ?? 0,
      revisionToken: entry?.revisionToken,
      reviewCursor: cursor,
      due: entry?.due,
    );
  }

  Future<MotherPatternSessionResult> recordSession({
    required String courseId,
    required Lesson lesson,
    required String sessionId,
    required MotherPatternState state,
    MotherPatternReviewSnapshot? reviewSnapshot,
  }) => learningStore.serializeSession((appendEvent) async {
    final pattern = lesson.patternLesson;
    if (courseId.trim().isEmpty ||
        lesson.id.trim().isEmpty ||
        sessionId.trim().isEmpty ||
        pattern == null) {
      throw ArgumentError(
        'A completed session requires course, lesson and session identity',
      );
    }
    final records = _records;
    final key = _patternKey(courseId, pattern);
    final record = records[key] as Map<String, dynamic>?;
    final sessions = Map<String, dynamic>.from(
      record?['sessions'] as Map? ?? const {},
    );
    final saved = sessions[sessionId] as Map<String, dynamic>?;
    // Return the original result before inspecting a now-stale snapshot.
    if (saved != null) {
      if (saved['logged'] != true) {
        await appendEvent(saved['event'] as Map<String, dynamic>);
        saved['logged'] = true;
        await _box.put(_storageKey, jsonEncode(records));
      }
      return MotherPatternSessionResult.fromJson(
        saved['result'] as Map<String, dynamic>,
      );
    }
    _validateSession(courseId, lesson, state, reviewSnapshot);
    final existing = _entry(record);
    final now = clock();
    var entry = existing;
    var reason = MotherPatternSaveReason.learning;
    var advance = false;
    var completedTraining = record?['completedTraining'];

    if (pattern.kind == PatternLessonKind.dialogue) {
      reason = MotherPatternSaveReason.dialogue;
    } else if (!state.isReview) {
      final success = state.independentSuccess;
      final stage = success ? (existing?.stage ?? 0) : 0;
      final due = !success
          ? now
          : existing?.due ?? now.add(const Duration(days: 1));
      entry = _newEntry(
        courseId,
        lesson,
        state,
        due: due,
        stage: stage,
        cursor: existing?.reviewCursor ?? 0,
        revision: (existing?.revision ?? 0) + 1,
      );
    } else {
      final snapshot = reviewSnapshot!;
      if (!snapshot.dueEligible) {
        reason = MotherPatternSaveReason.practice;
      } else if (!_trained(record, lesson) ||
          existing == null ||
          existing.revision != snapshot.revision ||
          existing.reviewCursor != snapshot.reviewCursor ||
          existing.revisionToken != snapshot.revisionToken ||
          existing.due != snapshot.due ||
          !_dueToday(existing.due, now)) {
        reason = MotherPatternSaveReason.staleReview;
      } else {
        reason = MotherPatternSaveReason.dueReview;
        advance = true;
        final success = state.independentSuccess;
        final stage = success ? (existing.stage + 1).clamp(1, 3) : 0;
        entry = _newEntry(
          courseId,
          lesson,
          state,
          due: now.add(Duration(days: success ? [0, 3, 7, 14][stage] : 0)),
          stage: stage,
          cursor: existing.reviewCursor + 2,
          revision: existing.revision + 1,
        );
      }
    }
    final result = MotherPatternSessionResult(
      entry: entry,
      scheduleAdvanced: advance,
      reason: reason,
    );
    final event = _event(courseId, lesson, sessionId, state, result);
    if (!state.isReview && pattern.kind == PatternLessonKind.pattern) {
      completedTraining = event;
    }
    final savedSession = {
      'result': result.toJson(),
      'event': event,
      'logged': false,
    };
    sessions[sessionId] = savedSession;
    records[key] = {
      'entry': entry?.toJson(),
      if (completedTraining != null) 'completedTraining': completedTraining,
      'latestSessionId': sessionId,
      'sessions': sessions,
    };
    // Ledger, full training evidence and original save result are one durable value.
    await _box.put(_storageKey, jsonEncode(records));
    await appendEvent(event);
    savedSession['logged'] = true;
    await _box.put(_storageKey, jsonEncode(records));
    return result;
  });

  void _validateSession(
    String courseId,
    Lesson lesson,
    MotherPatternState state,
    MotherPatternReviewSnapshot? snapshot,
  ) {
    final pattern = lesson.patternLesson!;
    pattern.validateExercises(lesson.exercises);
    if (!state.finished ||
        state.lessonId != lesson.id ||
        state.patternId != pattern.id ||
        state.patternVersion != pattern.version ||
        state.attemptedIds.length != state.totalCount ||
        state.totalCount != (state.isReview ? 2 : 10)) {
      throw ArgumentError(
        'Only a full finished state from the supplied lesson can be saved',
      );
    }
    if (state.isReview) {
      if (pattern.kind != PatternLessonKind.pattern ||
          snapshot == null ||
          snapshot.userKey != userKey ||
          snapshot.courseId != courseId ||
          snapshot.lessonId != lesson.id ||
          snapshot.patternId != pattern.id ||
          snapshot.patternVersion != pattern.version ||
          snapshot.exercises.length != 2 ||
          !_sameIds(state.exerciseIds, snapshot.exercises.map((e) => e.id))) {
        throw ArgumentError(
          'A review requires its original same-account and lesson snapshot',
        );
      }
      final expected = [
        for (var i = 0; i < 2; i++)
          pattern
              .review[(snapshot.reviewCursor + i) % pattern.review.length]
              .id,
      ];
      if (!_sameIds(state.exerciseIds, expected)) {
        throw ArgumentError('The review must match its saved rotation');
      }
    } else if (snapshot != null ||
        !_sameIds(state.exerciseIds, lesson.exercises.map((e) => e.id))) {
      throw ArgumentError(
        'Learning requires all ten scored exercises without a review snapshot',
      );
    }
  }

  bool _sameIds(List<String> actual, Iterable<String> expected) {
    final list = expected.toList();
    if (actual.length != list.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != list[i]) return false;
    }
    return true;
  }

  MotherPatternReviewEntry _newEntry(
    String courseId,
    Lesson lesson,
    MotherPatternState state, {
    required DateTime due,
    required int stage,
    required int cursor,
    required int revision,
  }) => MotherPatternReviewEntry(
    courseId: courseId,
    lessonId: lesson.id,
    patternId: lesson.patternLesson!.id,
    patternVersion: lesson.patternLesson!.version,
    due: due,
    stage: stage,
    reviewCursor: cursor,
    revision: revision,
    revisionToken: base64UrlEncode(
      List.generate(16, (_) => _random.nextInt(256)),
    ),
    firstCorrect: state.firstCorrectCount,
    totalCount: state.totalCount,
    hints: state.hintedCount,
  );

  Map<String, dynamic> _event(
    String courseId,
    Lesson lesson,
    String sessionId,
    MotherPatternState state,
    MotherPatternSessionResult result,
  ) => {
    'kind': 'motherPatternSession',
    'courseId': courseId,
    'lessonId': lesson.id,
    'patternId': lesson.patternLesson!.id,
    'patternVersion': lesson.patternLesson!.version,
    'patternKind': lesson.patternLesson!.kind.name,
    'sessionId': sessionId,
    'review': state.isReview,
    'independentSuccess': state.independentSuccess,
    'firstCorrect': state.firstCorrectCount,
    'totalCount': state.totalCount,
    'hints': state.hintedCount,
    'hintedIds': state.hintedIds.toList(),
    'typedFallbackIds': state.typedFallbackIds.toList(),
    'independentIds': state.independentIds.toList(),
    'independentCorrect': state.independentCorrectCount,
    'independentSpokenCorrect': state.independentSpokenCorrectCount,
    'independentTypedCorrect': state.independentTypedCorrectCount,
    'independentTypedFallbackCorrect':
        state.independentTypedFallbackCorrectCount,
    'firstSpokenCorrect': state.firstSpokenCorrectCount,
    'firstTypedCorrect': state.firstTypedCorrectCount,
    'firstTypedFallbackCorrect': state.firstTypedFallbackCorrectCount,
    'attempts': state.attempts.map((attempt) => attempt.toJson()).toList(),
    'scheduleAdvanced': result.scheduleAdvanced,
    'saveReason': result.reason.name,
    'completedAt': clock().toUtc().toIso8601String(),
  };
}
