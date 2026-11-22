import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/course.dart';
import '../models/pattern_training.dart';

class PatternReviewEntry {
  final DateTime due;
  final int stage;
  final int reviewCursor;
  final int firstCorrect;
  final int totalCount;
  final int hints;
  final String lessonId;

  const PatternReviewEntry({
    required this.due,
    required this.stage,
    required this.reviewCursor,
    required this.firstCorrect,
    required this.totalCount,
    required this.hints,
    required this.lessonId,
  });

  factory PatternReviewEntry.fromJson(Map<String, dynamic> json) =>
      PatternReviewEntry(
        due: DateTime.parse(json['due'] as String),
        stage: json['stage'] as int,
        reviewCursor: json['reviewCursor'] as int,
        firstCorrect: json['firstCorrect'] as int,
        totalCount: json['totalCount'] as int,
        hints: json['hints'] as int,
        lessonId: json['lessonId'] as String,
      );

  Map<String, dynamic> toJson() => {
    'due': due.toUtc().toIso8601String(),
    'stage': stage,
    'reviewCursor': reviewCursor,
    'firstCorrect': firstCorrect,
    'totalCount': totalCount,
    'hints': hints,
    'lessonId': lessonId,
  };
}

/// Account-scoped review scheduling and bounded local telemetry, without answers.
class LearningStore {
  static const boxName = 'learning_records';
  static final Map<String, Future<void>> _writes = {};
  final String userKey;
  final DateTime Function() clock;

  LearningStore({required this.userKey, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  Box<String> get _box => Hive.box<String>(boxName);
  String _key(String suffix) => '$userKey|$suffix';

  Map<String, dynamic> get reviews => _read('reviews', <String, dynamic>{});
  Map<String, dynamic> get patternReviews =>
      _read('patternReviews', <String, dynamic>{});
  Map<String, dynamic> get motherPatternReviews =>
      _read('motherPatternReviews', <String, dynamic>{});
  List<dynamic> get events => _eventState().feed;
  T _read<T>(String suffix, T fallback) {
    final raw = _box.get(_key(suffix));
    return raw == null ? fallback : jsonDecode(raw) as T;
  }

  // Shared by all stores for this user, including legacy telemetry writes.
  Future<T> _serialize<T>(Future<T> Function() action) {
    final previous = _writes[userKey] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _writes[userKey] = tail;
    tail.then((_) {
      if (identical(_writes[userKey], tail)) _writes.remove(userKey);
    });
    return result;
  }

  Future<void> log(Map<String, dynamic> event) => _serialize(() => _log(event));

  /// Keep a durable session save and its telemetry ordered with account clearing.
  /// The callback receives the raw append operation so it never nests the lock.
  Future<T> serializeSession<T>(
    Future<T> Function(Future<void> Function(Map<String, dynamic>) appendEvent)
    action,
  ) => _serialize(() => action(_log));

  String? _sessionEventIdentity(dynamic event) {
    if (event is! Map || event['kind'] != 'motherPatternSession') return null;
    return jsonEncode([
      event['kind'],
      event['courseId'],
      event['lessonId'],
      event['patternId'],
      event['patternVersion'],
      event['sessionId'],
    ]);
  }

  ({List<dynamic> feed, Set<String> identities}) _eventState() {
    final raw = _read<dynamic>('events', <dynamic>[]);
    if (raw is List) {
      // Legacy lists migrate on their next write. Capture identities before
      // bounding the feed so migration cannot lose an acknowledged append.
      final identities = <String>{};
      for (final event in raw) {
        final identity = _sessionEventIdentity(event);
        if (identity != null) identities.add(identity);
      }
      return (feed: raw, identities: identities);
    }
    final envelope = raw as Map<String, dynamic>;
    return (
      feed: envelope['events'] as List<dynamic>,
      identities: (envelope['motherPatternSessionIds'] as List)
          .cast<String>()
          .toSet(),
    );
  }

  Future<void> _log(Map<String, dynamic> event) async {
    final state = _eventState();
    final list = state.feed;
    final identity = _sessionEventIdentity(event);
    if (identity != null && !state.identities.add(identity)) return;
    list.add({...event, 'at': clock().toUtc().toIso8601String()});
    if (list.length > 2000) list.removeRange(0, list.length - 2000);
    // The append acknowledgement and bounded feed share one atomic Hive value.
    // A session-marker failure cannot later replay an evicted session event.
    await _box.put(
      _key('events'),
      jsonEncode({
        'version': 1,
        'events': list,
        'motherPatternSessionIds': state.identities.toList(),
      }),
    );
  }

  Future<void> recordAnswer({
    required String courseId,
    required String lessonId,
    required Exercise exercise,
    required bool correct,
    required bool first,
    required int elapsedMs,
    required String mode,
    bool skipped = false,
  }) => _serialize(() async {
    await _log({
      'kind': 'answer',
      'courseId': courseId,
      'lessonId': lessonId,
      'exerciseId': exercise.id,
      'type': exercise.type.name,
      'correct': correct,
      'first': first,
      'elapsedMs': elapsedMs,
      'mode': mode,
      'skipped': skipped,
    });
    if (skipped) return;
    if (mode == 'dialogue') return;
    if (mode == 'review' && !first) return;
    final map = reviews;
    final previous = map[exercise.id] as Map<String, dynamic>?;
    final existing = _isReviewForCourse(previous, courseId) ? previous : null;
    // In-session correction does not replace spaced review.
    if (mode != 'review' && correct) return;
    if (mode == 'review' && existing == null) return;
    final skillPractice =
        mode.startsWith('skill-') ||
        (mode == 'review' &&
            (_isPracticeReview(existing) ||
                _legacyPracticeReviewIds(courseId).contains(exercise.id)));
    final stage = correct
        ? ((existing?['stage'] as int? ?? 0) + 1).clamp(1, 4)
        : 0;
    final days = [0, 1, 3, 7, 14][stage];
    map[exercise.id] = {
      'lessonId': mode == 'review' && lessonId == 'practice'
          ? (existing?['lessonId'] ?? lessonId)
          : lessonId,
      'courseId': courseId,
      if (skillPractice) 'skillPractice': true,
      'stage': stage,
      'due': clock().add(Duration(days: days)).toUtc().toIso8601String(),
      'resolved': stage == 4,
    };
    await _box.put(_key('reviews'), jsonEncode(map));
  });

  String _patternKey(String courseId, PatternTraining training) =>
      jsonEncode([courseId, training.id, training.version]);

  PatternReviewEntry? patternReview(String courseId, PatternTraining training) {
    final value = patternReviews[_patternKey(courseId, training)];
    return value == null
        ? null
        : PatternReviewEntry.fromJson(value as Map<String, dynamic>);
  }

  List<Lesson> duePatternLessons(Course course, Set<String> completedLessons) {
    final entries = patternReviews;
    final localNow = clock().toLocal();
    final tomorrow = DateTime(localNow.year, localNow.month, localNow.day + 1);
    final candidates = <(Lesson, DateTime)>[];
    for (final lesson in course.orderedLessons) {
      final training = lesson.patternTraining;
      if (training == null || !completedLessons.contains(lesson.id)) continue;
      final raw = entries[_patternKey(course.id, training)];
      if (raw == null) continue;
      final entry = PatternReviewEntry.fromJson(raw as Map<String, dynamic>);
      if (entry.due.toLocal().isBefore(tomorrow)) {
        candidates.add((lesson, entry.due));
      }
    }
    candidates.sort((a, b) {
      final due = a.$2.compareTo(b.$2);
      return due != 0
          ? due
          : course
                .indexOfLesson(a.$1.id)
                .compareTo(course.indexOfLesson(b.$1.id));
    });
    return candidates.take(6).map((entry) => entry.$1).toList();
  }

  List<Exercise> patternReviewExercises(
    String courseId,
    PatternTraining training,
  ) {
    final cursor = patternReview(courseId, training)?.reviewCursor ?? 0;
    return [
      for (var i = 0; i < 2; i++)
        training.review[(cursor + i) % training.review.length],
    ];
  }

  Future<PatternReviewEntry> recordPatternSession({
    required String courseId,
    required String lessonId,
    required String sessionId,
    required PatternTraining training,
    required bool review,
    required bool independentSuccess,
    required int firstCorrect,
    required int totalCount,
    required int hints,
  }) => _serialize(() async {
    if (courseId.trim().isEmpty ||
        lessonId.trim().isEmpty ||
        sessionId.trim().isEmpty ||
        totalCount != (review ? 2 : 6) ||
        firstCorrect < 0 ||
        firstCorrect > totalCount ||
        hints < 0 ||
        hints > totalCount) {
      throw ArgumentError(
        'A pattern session requires complete exercises and valid summary counts',
      );
    }
    final map = patternReviews;
    final key = _patternKey(courseId, training);
    final raw = map[key] as Map<String, dynamic>?;
    final existing = raw == null ? null : PatternReviewEntry.fromJson(raw);
    final sessions = (raw?['sessions'] as List? ?? const [])
        .cast<String>()
        .toSet();
    if (sessions.contains(sessionId)) return existing!;
    final now = clock();
    final success = independentSuccess && (!review || hints == 0);
    var stage = existing?.stage ?? 0;
    var due = existing?.due ?? now;
    if (review) {
      stage = success ? (stage + 1).clamp(1, 3) : 0;
      due = now.add(Duration(days: success ? [0, 3, 7, 14][stage] : 0));
    } else if (!success) {
      stage = 0;
      due = now;
    } else if (existing == null) {
      due = now.add(const Duration(days: 1));
    }
    final entry = PatternReviewEntry(
      due: due,
      stage: stage,
      reviewCursor: (existing?.reviewCursor ?? 0) + (review ? 2 : 0),
      firstCorrect: firstCorrect,
      totalCount: totalCount,
      hints: hints,
      lessonId: lessonId,
    );
    sessions.add(sessionId);
    map[key] = {...entry.toJson(), 'sessions': sessions.toList()};
    // Session identity and scheduling share one Hive value for durable deduplication.
    await _box.put(_key('patternReviews'), jsonEncode(map));
    await _log({
      'kind': 'patternSession',
      'courseId': courseId,
      'lessonId': lessonId,
      'patternId': training.id,
      'patternVersion': training.version,
      'sessionId': sessionId,
      'review': review,
      'independentSuccess': success,
      'firstCorrect': firstCorrect,
      'totalCount': totalCount,
      'hints': hints,
    });
    return entry;
  });

  bool _isDue(Object? record, DateTime now) {
    if (record is! Map || record['resolved'] == true) return false;
    final due = record['due'];
    final date = due is String ? DateTime.tryParse(due) : null;
    return date != null && !date.isAfter(now);
  }

  bool _isReviewForCourse(Object? record, String courseId) =>
      record is Map &&
      (record['courseId'] == courseId || record['courseId'] == null);

  bool _isPracticeReview(Object? record) {
    if (record is! Map) return false;
    if (record['skillPractice'] == true) return true;
    final lessonId = record['lessonId'];
    return lessonId is String &&
        (lessonId.startsWith('practice-') || lessonId == 'practice');
  }

  // Older records used the system lesson ID whenever a bank shared its exercise.
  // Recover the source from the latest wrong answer that created that schedule.
  Set<String> _legacyPracticeReviewIds(String courseId) {
    final seen = <String>{};
    final practiceIds = <String>{};
    for (final event in events.reversed) {
      if (event
          case {
            'kind': 'answer',
            'courseId': final eventCourse,
            'exerciseId': final String id,
            'correct': false,
            'mode': final String mode,
          }
          when eventCourse == courseId &&
              mode != 'review' &&
              mode != 'dialogue' &&
              event['skipped'] != true &&
              seen.add(id)) {
        if (mode.startsWith('skill-')) practiceIds.add(id);
      }
    }
    return practiceIds;
  }

  bool hasDuePracticeReviews(String courseId) {
    final now = clock();
    final candidates = reviews.entries.where(
      (entry) =>
          _isReviewForCourse(entry.value, courseId) && _isDue(entry.value, now),
    );
    if (candidates.isEmpty) return false;
    if (candidates.any((entry) => _isPracticeReview(entry.value))) return true;
    final practiceIds = _legacyPracticeReviewIds(courseId);
    return candidates.any((entry) => practiceIds.contains(entry.key));
  }

  List<Exercise> dueExercises(
    Course course,
    Set<String> unlockedLessons, {
    Iterable<Exercise> practiceExercises = const [],
  }) {
    final map = reviews;
    final now = clock();
    final due = <String, Exercise>{};
    for (final lesson in course.orderedLessons) {
      if (!unlockedLessons.contains(lesson.id)) continue;
      for (final exercise in lesson.exercises) {
        final record = map[exercise.id];
        if (_isReviewForCourse(record, course.id) && _isDue(record, now)) {
          due.putIfAbsent(exercise.id, () => exercise);
        }
      }
    }
    final practiceIds = practiceExercises.isEmpty
        ? const <String>{}
        : _legacyPracticeReviewIds(course.id);
    for (final exercise in practiceExercises) {
      final record = map[exercise.id];
      if (_isReviewForCourse(record, course.id) &&
          _isDue(record, now) &&
          (_isPracticeReview(record) || practiceIds.contains(exercise.id))) {
        due.putIfAbsent(exercise.id, () => exercise);
      }
    }
    final candidates = due.values.toList();
    candidates.sort(
      (a, b) =>
          (map[a.id]['due'] as String).compareTo(map[b.id]['due'] as String),
    );
    return candidates.take(12).toList();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'version': 1,
    'events': events,
    'reviews': reviews,
    'patternReviews': patternReviews,
    'motherPatternReviews': motherPatternReviews,
  });

  Future<void> clear() => _serialize(() async {
    await _box.delete(_key('events'));
    await _box.delete(_key('reviews'));
    await _box.delete(_key('patternReviews'));
    await _box.delete(_key('motherPatternReviews'));
  });
}
