import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/course_track.dart';
import '../../data/models/lesson_badge.dart';

class RewardsPage extends ConsumerWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(rewardRevisionProvider);
    final courses = ref.watch(allCoursesProvider).requireValue;
    final rewards = ref.watch(rewardRepositoryProvider);
    if (rewards == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('徽章')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final rows = <Widget>[];
    for (final course in courses) {
      final track = CourseTrack.fromId(course.id);
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text(
            track.label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.greenDark,
            ),
          ),
        ),
      );
      for (final unit in course.units) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
            child: Text(
              unit.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
        for (final lesson in unit.lessons) {
          final count = rewards.countFor(lesson.id);
          final unlocked = rewards.isLessonBadgeUnlocked(lesson.id, unit.id);
          final style = LessonBadgeStyle.forLesson(lesson.id);
          rows.add(
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 4,
              ),
              leading: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  unlocked ? style.icon : Icons.lock_outline_rounded,
                  size: 30,
                  color: unlocked ? style.color : AppColors.lockedDark,
                ),
              ),
              title: Text(
                lesson.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                unlocked
                    ? (count > 0 ? '×$count' : '已获得')
                    : '未获得徽章',
                style: TextStyle(
                  color: unlocked
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('徽章')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: rows,
      ),
    );
  }
}
