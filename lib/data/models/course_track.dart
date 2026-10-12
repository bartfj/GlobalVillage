import 'learning_language.dart';

/// 各学习语言的具体系统课程。
enum CourseTrack {
  zero,
  beginner,
  intermediate,
  chinese,
  sanskrit;

  LearningLanguage get language => switch (this) {
    chinese => LearningLanguage.chinese,
    sanskrit => LearningLanguage.sanskrit,
    _ => LearningLanguage.english,
  };

  String get id => name;

  String get label => switch (this) {
    CourseTrack.zero => '零基础',
    CourseTrack.beginner => '初级',
    CourseTrack.intermediate => '中级',
    CourseTrack.chinese => '普通话入门',
    CourseTrack.sanskrit => '梵文入门',
  };

  String get assetPath => switch (this) {
    CourseTrack.zero => 'assets/courses/course_zero.json',
    CourseTrack.beginner => 'assets/courses/course_beginner.json',
    CourseTrack.intermediate => 'assets/courses/course_intermediate.json',
    CourseTrack.chinese => 'assets/courses/course_chinese.json',
    CourseTrack.sanskrit => 'assets/courses/course_sanskrit.json',
  };

  static CourseTrack fromId(String? id) {
    if (id == null) return CourseTrack.beginner;
    // 兼容旧设置里的 elementary → 初级
    if (id == 'elementary') return CourseTrack.beginner;
    for (final track in CourseTrack.values) {
      if (track.id == id) return track;
    }
    return CourseTrack.beginner;
  }
}
