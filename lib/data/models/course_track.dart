import 'learning_language.dart';

/// 各学习语言的具体系统课程。
enum CourseTrack {
  zero,
  beginner,
  intermediate,
  chineseZero,
  chinese,
  sanskritZero,
  sanskrit;

  LearningLanguage get language => switch (this) {
    chineseZero || chinese => LearningLanguage.chinese,
    sanskritZero || sanskrit => LearningLanguage.sanskrit,
    _ => LearningLanguage.english,
  };

  String get id => name;

  String get label => switch (this) {
    CourseTrack.zero => '零基础',
    CourseTrack.beginner => '初级',
    CourseTrack.intermediate => '中级',
    CourseTrack.chineseZero => '中文零基础',
    CourseTrack.chinese => '普通话入门',
    CourseTrack.sanskritZero => '梵文零基础',
    CourseTrack.sanskrit => '梵文入门',
  };

  String get assetPath => switch (this) {
    CourseTrack.zero => 'assets/courses/course_zero.json',
    CourseTrack.beginner => 'assets/courses/course_beginner.json',
    CourseTrack.intermediate => 'assets/courses/course_intermediate.json',
    CourseTrack.chineseZero => 'assets/courses/course_chinese_zero.json',
    CourseTrack.chinese => 'assets/courses/course_chinese.json',
    CourseTrack.sanskritZero => 'assets/courses/course_sanskrit_zero.json',
    CourseTrack.sanskrit => 'assets/courses/course_sanskrit.json',
  };

  /// 零基础课程完成后推荐的下一级课程；其余轨道没有默认后续。
  CourseTrack? get nextTrack => switch (this) {
    CourseTrack.chineseZero => CourseTrack.chinese,
    CourseTrack.sanskritZero => CourseTrack.sanskrit,
    _ => null,
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
