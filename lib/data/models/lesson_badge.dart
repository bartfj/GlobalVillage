import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 每关确定性徽章样式（图标 + 底色），保证相邻关观感不同
class LessonBadgeStyle {
  const LessonBadgeStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  static const icons = <IconData>[
    Icons.waving_hand_rounded,
    Icons.schedule_rounded,
    Icons.people_rounded,
    Icons.restaurant_rounded,
    Icons.palette_rounded,
    Icons.directions_run_rounded,
    Icons.wb_sunny_rounded,
    Icons.train_rounded,
    Icons.shopping_bag_rounded,
    Icons.favorite_rounded,
    Icons.school_rounded,
    Icons.sports_esports_rounded,
    Icons.diversity_3_rounded,
    Icons.public_rounded,
    Icons.pets_rounded,
    Icons.home_rounded,
    Icons.music_note_rounded,
    Icons.local_cafe_rounded,
    Icons.flight_rounded,
    Icons.beach_access_rounded,
    Icons.forest_rounded,
    Icons.water_drop_rounded,
    Icons.star_rounded,
    Icons.emoji_events_rounded,
    Icons.lightbulb_rounded,
    Icons.auto_stories_rounded,
    Icons.phonelink_ring_rounded,
    Icons.directions_bike_rounded,
    Icons.local_florist_rounded,
    Icons.nightlight_round,
    Icons.umbrella_rounded,
    Icons.cake_rounded,
  ];

  static const colors = <Color>[
    AppColors.green,
    AppColors.blue,
    AppColors.goldDark,
    AppColors.red,
    AppColors.greenDark,
  ];

  static int _seed(String lessonId) {
    var h = 0;
    for (final c in lessonId.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  static LessonBadgeStyle forLesson(String lessonId) {
    final seed = _seed(lessonId);
    // 错开图标与颜色周期，减少相邻关撞款
    final icon = icons[seed % icons.length];
    final color = colors[(seed ~/ 7) % colors.length];
    return LessonBadgeStyle(icon: icon, color: color);
  }
}
