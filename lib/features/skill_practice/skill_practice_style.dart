import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/skill_practice.dart';

/// 各专项的图标与主题色，练习页与侧栏共用
extension SkillPracticeStyle on SkillPracticeKind {
  Color get accent {
    switch (this) {
      case SkillPracticeKind.pronunciation:
        return AppColors.blue;
      case SkillPracticeKind.vocabulary:
        return AppColors.goldDark;
      case SkillPracticeKind.speaking:
        return AppColors.green;
      case SkillPracticeKind.englishYoga:
        return AppColors.greenDark;
      case SkillPracticeKind.chineseTones:
        return AppColors.red;
      case SkillPracticeKind.chineseCharacters:
        return AppColors.blueDark;
      case SkillPracticeKind.sanskritLetters:
        return AppColors.goldDark;
      case SkillPracticeKind.sanskritVowels:
        return AppColors.greenDark;
      case SkillPracticeKind.sanskritYoga:
        return AppColors.gold;
    }
  }

  IconData get icon {
    switch (this) {
      case SkillPracticeKind.pronunciation:
        return Icons.hearing_rounded;
      case SkillPracticeKind.vocabulary:
        return Icons.menu_book_rounded;
      case SkillPracticeKind.speaking:
        return Icons.record_voice_over_rounded;
      case SkillPracticeKind.englishYoga:
        return Icons.sports_gymnastics_rounded;
      case SkillPracticeKind.chineseTones:
        return Icons.graphic_eq_rounded;
      case SkillPracticeKind.chineseCharacters:
        return Icons.text_fields_rounded;
      case SkillPracticeKind.sanskritLetters:
        return Icons.language_rounded;
      case SkillPracticeKind.sanskritVowels:
        return Icons.swap_horiz_rounded;
      case SkillPracticeKind.sanskritYoga:
        return Icons.self_improvement_rounded;
    }
  }
}
