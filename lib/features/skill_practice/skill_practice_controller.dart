import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/course.dart';
import '../../data/models/skill_practice.dart';
import '../lesson/lesson_controller.dart';

/// 专项会话包装：复用课时判分状态机，但用独立 provider 与课时队列隔离
class SkillPracticeSession {
  final SkillPracticeKind skill;
  final String chapterId;
  final Lesson lesson;

  const SkillPracticeSession({
    required this.skill,
    required this.chapterId,
    required this.lesson,
  });

  String get mode => skill.modeForChapter(chapterId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillPracticeSession &&
          skill == other.skill &&
          chapterId == other.chapterId &&
          lesson.id == other.lesson.id;

  @override
  int get hashCode => Object.hash(skill, chapterId, lesson.id);
}

final skillPracticeControllerProvider = StateNotifierProvider.autoDispose
    .family<LessonController, LessonState, SkillPracticeSession>(
      (ref, session) => LessonController(session.lesson),
    );
