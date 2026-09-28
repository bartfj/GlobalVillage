/// 学习内容大类：零基础 / 初级
enum CourseTrack {
  zero,
  beginner;

  String get id => name;

  String get label => switch (this) {
    CourseTrack.zero => '零基础',
    CourseTrack.beginner => '初级',
  };

  String get assetPath => switch (this) {
    CourseTrack.zero => 'assets/courses/course_zero.json',
    CourseTrack.beginner => 'assets/courses/course_beginner.json',
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
