enum LearningLanguage {
  english,
  chinese,
  sanskrit;

  String get label => switch (this) {
    english => '英语',
    chinese => '中文 Chinese',
    sanskrit => '梵文 Sanskrit',
  };

  String get shortLabel => switch (this) {
    english => '英语',
    chinese => '中文',
    sanskrit => '梵文',
  };
}
