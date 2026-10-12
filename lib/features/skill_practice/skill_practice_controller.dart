import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/course.dart';
import '../../data/models/skill_practice.dart';
import '../lesson/lesson_controller.dart';

/// 专项会话包装：复用课时判分状态机，但用独立 provider 与课时队列隔离
class SkillPracticeSession {
  final SkillPracticeKind skill;
  final Lesson lesson;

  const SkillPracticeSession({required this.skill, required this.lesson});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillPracticeSession &&
          skill == other.skill &&
          lesson.id == other.lesson.id;

  @override
  int get hashCode => Object.hash(skill, lesson.id);
}

final skillPracticeControllerProvider = StateNotifierProvider.autoDispose
    .family<LessonController, LessonState, SkillPracticeSession>(
      (ref, session) => LessonController(session.lesson),
    );
