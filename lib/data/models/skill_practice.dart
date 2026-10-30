import 'course.dart';
import 'learning_language.dart';

/// 专项练习技能：英语（发音/单词/口语）+ 中文（声调/汉字）+ 梵文（字母/元音/瑜伽）
enum SkillPracticeKind {
  pronunciation,
  vocabulary,
  speaking,
  englishYoga,
  chineseTones,
  chineseCharacters,
  sanskritLetters,
  sanskritVowels,
  sanskritYoga;

  String get assetPath => 'assets/practice/$name.json';

  String get mode => 'skill-$name';

  /// 学习日志 mode，带章节时为 `skill-<name>/<chapterId>`
  String modeForChapter(String chapterId) => '$mode/$chapterId';

  /// 该专项所属的学习语言；路由与侧栏按此过滤
  LearningLanguage get language {
    switch (this) {
      case SkillPracticeKind.pronunciation:
      case SkillPracticeKind.vocabulary:
      case SkillPracticeKind.speaking:
      case SkillPracticeKind.englishYoga:
        return LearningLanguage.english;
      case SkillPracticeKind.chineseTones:
      case SkillPracticeKind.chineseCharacters:
        return LearningLanguage.chinese;
      case SkillPracticeKind.sanskritLetters:
      case SkillPracticeKind.sanskritVowels:
      case SkillPracticeKind.sanskritYoga:
        return LearningLanguage.sanskrit;
    }
  }

  /// 某语言可用的专项列表（保持枚举声明顺序）
  static List<SkillPracticeKind> forLanguage(LearningLanguage language) =>
      values.where((k) => k.language == language).toList();

  String get title {
    switch (this) {
      case SkillPracticeKind.pronunciation:
        return '发音练习';
      case SkillPracticeKind.vocabulary:
        return '单词练习';
      case SkillPracticeKind.speaking:
        return '口语练习';
      case SkillPracticeKind.englishYoga:
        return '瑜伽英文';
      case SkillPracticeKind.chineseTones:
        return '声调练习';
      case SkillPracticeKind.chineseCharacters:
        return '汉字识读';
      case SkillPracticeKind.sanskritLetters:
        return '天城体辨认';
      case SkillPracticeKind.sanskritVowels:
        return '长短元音辨析';
      case SkillPracticeKind.sanskritYoga:
        return '瑜伽梵文';
    }
  }

  String get subtitle {
    switch (this) {
      case SkillPracticeKind.pronunciation:
        return '听清发音，跟读模仿';
      case SkillPracticeKind.vocabulary:
        return '巩固词义、拼写与搭配';
      case SkillPracticeKind.speaking:
        return '大声说出来，练受控输出';
      case SkillPracticeKind.englishYoga:
        return '听懂课堂术语与指令';
      case SkillPracticeKind.chineseTones:
        return '四声对比，选准调号';
      case SkillPracticeKind.chineseCharacters:
        return '看字读音，见字知义';
      case SkillPracticeKind.sanskritLetters:
        return '认读天城体字母与音节';
      case SkillPracticeKind.sanskritVowels:
        return '分清长短元音，读准转写';
      case SkillPracticeKind.sanskritYoga:
        return '认读课堂常用瑜伽术语';
    }
  }

  String get doneTitle {
    switch (this) {
      case SkillPracticeKind.pronunciation:
        return '发音练习完成';
      case SkillPracticeKind.vocabulary:
        return '单词练习完成';
      case SkillPracticeKind.speaking:
        return '口语练习完成';
      case SkillPracticeKind.englishYoga:
        return '瑜伽英文完成';
      case SkillPracticeKind.chineseTones:
        return '声调练习完成';
      case SkillPracticeKind.chineseCharacters:
        return '汉字识读完成';
      case SkillPracticeKind.sanskritLetters:
        return '天城体辨认完成';
      case SkillPracticeKind.sanskritVowels:
        return '长短元音辨析完成';
      case SkillPracticeKind.sanskritYoga:
        return '瑜伽梵文完成';
    }
  }

  static SkillPracticeKind? tryParse(String raw) {
    for (final kind in values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }
}

/// 专项练习的一章（解锁顺序 = [SkillPracticeBank.chapters] 下标顺序）
class SkillPracticeChapter {
  final String id;
  final String title;
  final String? subtitle;
  final List<Exercise> exercises;

  const SkillPracticeChapter({
    required this.id,
    required this.title,
    this.subtitle,
    required this.exercises,
  });

  factory SkillPracticeChapter.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    if (id.isEmpty) {
      throw FormatException('Chapter id is required');
    }
    return SkillPracticeChapter(
      id: id,
      title: json['title'] as String? ?? id,
      subtitle: json['subtitle'] as String?,
      exercises: (json['exercises'] as List<dynamic>? ?? const [])
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SkillPracticeBank {
  final SkillPracticeKind skill;
  final String title;
  final List<SkillPracticeChapter> chapters;

  const SkillPracticeBank({
    required this.skill,
    required this.title,
    required this.chapters,
  });

  /// 全部章节题目扁平列表（兼容旧调用方）
  List<Exercise> get exercises => [
        for (final chapter in chapters) ...chapter.exercises,
      ];

  SkillPracticeChapter? chapterById(String id) {
    for (final chapter in chapters) {
      if (chapter.id == id) return chapter;
    }
    return null;
  }

  factory SkillPracticeBank.fromJson(Map<String, dynamic> json) {
    final skillName = json['skill'] as String;
    final skill = SkillPracticeKind.tryParse(skillName);
    if (skill == null) {
      throw FormatException('Unknown skill: $skillName');
    }

    final title = json['title'] as String? ?? skill.title;
    final rawChapters = json['chapters'] as List<dynamic>?;
    if (rawChapters != null && rawChapters.isNotEmpty) {
      return SkillPracticeBank(
        skill: skill,
        title: title,
        chapters: rawChapters
            .map((e) => SkillPracticeChapter.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }

    final flat = (json['exercises'] as List<dynamic>? ?? const [])
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
    return SkillPracticeBank(
      skill: skill,
      title: title,
      chapters: [
        SkillPracticeChapter(
          id: 'default',
          title: title,
          subtitle: skill.subtitle,
          exercises: flat,
        ),
      ],
    );
  }
}
