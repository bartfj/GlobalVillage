import '../../core/constants.dart';
import '../models/course.dart';
import '../models/progress.dart';
import '../sources/progress_store.dart';

/// 进度仓库：查询完成状态、判定解锁、回写学习结果
class ProgressRepository {
  final ProgressStore store;
  final Course course;

  const ProgressRepository({required this.store, required this.course});

  bool isLessonCompleted(String lessonId) =>
      store.get(lessonId)?.completed ?? false;

  /// 解锁规则：第一课始终解锁；其余课程要求前一课已完成
  /// （完成 = 正确率 >= [kPassThreshold]，见 [recordResult]）
  bool isLessonUnlocked(String lessonId) {
    final ordered = course.orderedLessons;
    final index = ordered.indexWhere((l) => l.id == lessonId);
    if (index < 0) return false;
    if (index == 0) return true;
    return store.get(ordered[index - 1].id)?.completed ?? false;
  }

  /// 当前可学习且未完成的一课；仅供临时跳关入口使用。
  Lesson? get currentLesson {
    for (final lesson in course.orderedLessons) {
      if (!isLessonCompleted(lesson.id) && isLessonUnlocked(lesson.id)) {
        return lesson;
      }
    }
    return null;
  }

  /// 临时跳过当前关卡，不伪造答题成绩。
  Future<Lesson?> skipCurrentLesson() async {
    final lesson = currentLesson;
    if (lesson == null) return null;
    await store.save(LessonProgress(
      lessonId: lesson.id,
      completed: true,
      score: 0,
      correctCount: 0,
      totalCount: 0,
      completedAt: DateTime.now(),
    ));
    return lesson;
  }

  /// 回写一课的学习结果。正确率达到阈值标记完成并保留最好成绩。
  Future<bool> recordResult({
    required String lessonId,
    required int correctCount,
    required int totalCount,
  }) async {
    final passed = totalCount > 0 && correctCount / totalCount >= kPassThreshold;
    final existing = store.get(lessonId);
    // 仅在新纪录或首次通关时覆盖，避免重学刷低历史成绩
    final betterScore = correctCount > (existing?.correctCount ?? -1);
    if (existing == null || betterScore || (!existing.completed && passed)) {
      await store.save(
        LessonProgress(
          lessonId: lessonId,
          completed: (existing?.completed ?? false) || passed,
          score: totalCount == 0
              ? 0
              : (correctCount * 100 / totalCount).round(),
          correctCount: correctCount,
          totalCount: totalCount,
          completedAt: passed
              ? (existing?.completedAt ?? DateTime.now())
              : existing?.completedAt,
        ),
      );
    }
    return passed;
  }
}
