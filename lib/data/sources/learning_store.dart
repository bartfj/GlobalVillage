import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/course.dart';

/// Account-scoped review scheduling and bounded local telemetry, without answers.
class LearningStore {
  static const boxName = 'learning_records';
  final String userKey;
  final DateTime Function() clock;

  LearningStore({required this.userKey, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  Box<String> get _box => Hive.box<String>(boxName);
  String _key(String suffix) => '$userKey|$suffix';

  Map<String, dynamic> get reviews => _read('reviews', <String, dynamic>{});
  List<dynamic> get events => _read('events', <dynamic>[]);
  T _read<T>(String suffix, T fallback) {
    final raw = _box.get(_key(suffix));
    return raw == null ? fallback : jsonDecode(raw) as T;
  }

  Future<void> log(Map<String, dynamic> event) async {
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
  }) async {
    await log({
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
  }

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

  String exportJson() => const JsonEncoder.withIndent(
    '  ',
  ).convert({'version': 1, 'events': events, 'reviews': reviews});

  Future<void> clear() async {
    await _box.delete(_key('events'));
    await _box.delete(_key('reviews'));
  }
}
