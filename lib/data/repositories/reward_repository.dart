import '../models/course.dart';
import '../sources/reward_store.dart';

class RewardAward {
  final Lesson lesson;
  final Unit unit;
  final int count;
  final bool newlyAwarded;

  const RewardAward({
    required this.lesson,
    required this.unit,
    required this.count,
    required this.newlyAwarded,
  });
}

class RewardRepository {
  final RewardStore store;
  final Course course;

  /// 新奖励入账后触发（在线会话的同步防抖上传）
  final void Function()? onAwarded;
  final int Function()? readBonusTrees;

  const RewardRepository({
    required this.store,
    required this.course,
    this.onAwarded,
    this.readBonusTrees,
  });

  /// 某关徽章获得次数（存储值为 lessonId）
  int countFor(String lessonId) =>
      store.attempts.values.where((id) => id == lessonId).length;

  /// 已解锁徽章的关卡数（全局；兼容旧备份里存的 unitId）
  int unlockedBadgeCount(Iterable<Course> courses) {
    final subjects = store.attempts.values.toSet();
    var n = 0;
    for (final c in courses) {
      for (final u in c.units) {
        final unitLegacy = subjects.contains(u.id);
        for (final lesson in u.lessons) {
          if (subjects.contains(lesson.id) || unitLegacy) n++;
        }
      }
    }
    return n;
  }

  bool isLessonBadgeUnlocked(String lessonId, String unitId) {
    if (countFor(lessonId) > 0) return true;
    return store.attempts.values.contains(unitId);
  }

  /// 梭梭树总数包含通关奖励与连续打卡奖励。
  int get treeCount => store.attempts.length + (readBonusTrees?.call() ?? 0);

  Future<RewardAward?> awardForPassedAttempt(
    String lessonId,
    String attemptId,
  ) async {
    if (attemptId.isEmpty) return null;
    Unit? unit;
    Lesson? lesson;
    for (final candidate in course.units) {
      for (final item in candidate.lessons) {
        if (item.id == lessonId) {
          unit = candidate;
          lesson = item;
          break;
        }
      }
      if (lesson != null) break;
    }
    if (unit == null || lesson == null) return null;

    final existing = store.get(attemptId);
    // 允许旧 attempt 存 unitId：同一 attempt 不重复写入
    if (existing != null &&
        existing != lesson.id &&
        existing != unit.id) {
      return null;
    }
    if (existing == null) {
      await store.save(attemptId, lesson.id);
      onAwarded?.call();
    }
    return RewardAward(
      lesson: lesson,
      unit: unit,
      count: countFor(lesson.id),
      newlyAwarded: existing == null,
    );
  }
}
