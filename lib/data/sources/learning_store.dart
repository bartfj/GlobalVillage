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
  List<dynamic> get events => _read('events', <dynamic>[]);
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

  Future<void> _log(Map<String, dynamic> event) async {
    final list = events;
    list.add({...event, 'at': clock().toUtc().toIso8601String()});
    if (list.length > 2000) list.removeRange(0, list.length - 2000);
    await _box.put(_key('events'), jsonEncode(list));
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
    final existing = map[exercise.id] as Map<String, dynamic>?;
    // In-session correction does not replace spaced review.
    if (mode != 'review' && correct) return;
    if (existing == null && correct) return;
    final stage = correct
        ? ((existing?['stage'] as int? ?? 0) + 1).clamp(1, 4)
        : 0;
    final days = [0, 1, 3, 7, 14][stage];
    map[exercise.id] = {
      'lessonId': lessonId,
      'courseId': courseId,
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

  List<Exercise> dueExercises(Course course, Set<String> unlockedLessons) {
    final map = reviews;
    final candidates = course.orderedLessons
        .where((l) => unlockedLessons.contains(l.id))
        .expand((l) => l.exercises)
        .where((e) {
          final r = map[e.id] as Map<String, dynamic>?;
          return r != null &&
              r['resolved'] != true &&
              !DateTime.parse(r['due'] as String).isAfter(clock());
        })
        .toList();
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
  });

  Future<void> clear() => _serialize(() async {
    await _box.delete(_key('events'));
    await _box.delete(_key('reviews'));
    await _box.delete(_key('patternReviews'));
  });
}
