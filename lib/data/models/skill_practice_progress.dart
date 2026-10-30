/// 专项章节完成门槛（一轮正确率）
const double skillPracticePassAccuracy = 0.8;

/// 单章本地进度
class SkillPracticeChapterProgress {
  final String skill;
  final String chapterId;
  final bool completed;
  final double bestAccuracy;
  final double lastAccuracy;
  final DateTime? lastPlayedAt;

  const SkillPracticeChapterProgress({
    required this.skill,
    required this.chapterId,
    required this.completed,
    required this.bestAccuracy,
    required this.lastAccuracy,
    this.lastPlayedAt,
  });

  Map<String, dynamic> toJson() => {
        'skill': skill,
        'chapterId': chapterId,
        'completed': completed,
        'bestAccuracy': bestAccuracy,
        'lastAccuracy': lastAccuracy,
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      };

  factory SkillPracticeChapterProgress.fromJson(Map<String, dynamic> json) {
    return SkillPracticeChapterProgress(
      skill: json['skill'] as String,
      chapterId: json['chapterId'] as String,
      completed: json['completed'] as bool? ?? false,
      bestAccuracy: (json['bestAccuracy'] as num?)?.toDouble() ?? 0,
      lastAccuracy: (json['lastAccuracy'] as num?)?.toDouble() ?? 0,
      lastPlayedAt: json['lastPlayedAt'] == null
          ? null
          : DateTime.tryParse(json['lastPlayedAt'] as String),
    );
  }
}

/// 章节在地图上的展示状态
enum SkillPracticeChapterStatus {
  locked,
  available,
  completed,
}

/// 第 [index] 章是否已解锁（第 0 章永远解锁；前一章 completed 才开下一章）
bool isSkillPracticeChapterUnlocked({
  required int index,
  required List<bool> chapterCompletedFlags,
}) {
  if (index <= 0) return true;
  if (index >= chapterCompletedFlags.length) return false;
  return chapterCompletedFlags[index - 1];
}

SkillPracticeChapterStatus skillPracticeChapterStatus({
  required int index,
  required List<bool> chapterCompletedFlags,
}) {
  if (index < chapterCompletedFlags.length && chapterCompletedFlags[index]) {
    return SkillPracticeChapterStatus.completed;
  }
  if (isSkillPracticeChapterUnlocked(
    index: index,
    chapterCompletedFlags: chapterCompletedFlags,
  )) {
    return SkillPracticeChapterStatus.available;
  }
  return SkillPracticeChapterStatus.locked;
}

/// 根据本轮正确率合并进度；已完成不降级
SkillPracticeChapterProgress applySkillPracticeSessionResult({
  required String skill,
  required String chapterId,
  required int correctCount,
  required int totalCount,
  SkillPracticeChapterProgress? previous,
  DateTime? now,
}) {
  final playedAt = now ?? DateTime.now();
  final accuracy = totalCount <= 0 ? 0.0 : correctCount / totalCount;
  final passed = accuracy >= skillPracticePassAccuracy;
  final prevBest = previous?.bestAccuracy ?? 0;
  final wasCompleted = previous?.completed ?? false;

  return SkillPracticeChapterProgress(
    skill: skill,
    chapterId: chapterId,
    completed: wasCompleted || passed,
    bestAccuracy: accuracy > prevBest ? accuracy : prevBest,
    lastAccuracy: accuracy,
    lastPlayedAt: playedAt,
  );
}
