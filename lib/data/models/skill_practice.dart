import 'course.dart';

/// 专项练习技能：发音 / 单词 / 口语
enum SkillPracticeKind {
  pronunciation,
  vocabulary,
  speaking;

  String get assetPath => 'assets/practice/$name.json';

  String get mode => 'skill-$name';

  String get title {
    switch (this) {
      case SkillPracticeKind.pronunciation:
        return '发音练习';
      case SkillPracticeKind.vocabulary:
        return '单词练习';
      case SkillPracticeKind.speaking:
        return '口语练习';
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
    }
  }

  static SkillPracticeKind? tryParse(String raw) {
    for (final kind in values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }
}

class SkillPracticeBank {
  final SkillPracticeKind skill;
  final String title;
  final List<Exercise> exercises;

  const SkillPracticeBank({
    required this.skill,
    required this.title,
    required this.exercises,
  });

  factory SkillPracticeBank.fromJson(Map<String, dynamic> json) {
    final skillName = json['skill'] as String;
    final skill = SkillPracticeKind.tryParse(skillName);
    if (skill == null) {
      throw FormatException('Unknown skill: $skillName');
    }
    return SkillPracticeBank(
      skill: skill,
      title: json['title'] as String? ?? skill.title,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
