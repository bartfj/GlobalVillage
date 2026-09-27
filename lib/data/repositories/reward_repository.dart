import '../models/course.dart';
import '../sources/reward_store.dart';

class RewardAward {
  final Unit unit;
  final int count;
  final bool newlyAwarded;

  const RewardAward(this.unit, this.count, this.newlyAwarded);
}

class RewardRepository {
  final RewardStore store;
  final Course course;

  const RewardRepository({required this.store, required this.course});

  int countFor(String unitId) =>
      store.attempts.values.where((id) => id == unitId).length;

  /// 梭梭树总数 = 累计通关次数（每次通关存一条记录，attemptId 幂等、按账号隔离）
  int get treeCount => store.attempts.length;

  Future<RewardAward?> awardForPassedAttempt(
    String lessonId,
    String attemptId,
  ) async {
    if (attemptId.isEmpty) return null;
    Unit? unit;
    for (final candidate in course.units) {
      if (candidate.lessons.any((lesson) => lesson.id == lessonId)) {
        unit = candidate;
        break;
      }
    }
    if (unit == null) return null;
    final existing = store.get(attemptId);
    if (existing != null && existing != unit.id) return null;
    if (existing == null) await store.save(attemptId, unit.id);
    return RewardAward(unit, countFor(unit.id), existing == null);
  }
}
