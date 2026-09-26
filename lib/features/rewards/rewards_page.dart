import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

class RewardsPage extends ConsumerWidget {
  const RewardsPage({super.key});

  static const _icons = [
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
  ];
  static const _colors = [
    AppColors.green,
    AppColors.blue,
    AppColors.goldDark,
    AppColors.red,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(rewardRevisionProvider);
    final units = ref.watch(courseProvider).requireValue.units;
    final rewards = ref.watch(rewardRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('收藏')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: units.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final unit = units[index];
          final count = rewards.countFor(unit.id);
          final unlocked = count > 0;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 4,
            ),
            leading: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                unlocked
                    ? _icons[index % _icons.length]
                    : Icons.lock_outline_rounded,
                size: 30,
                color: unlocked
                    ? _colors[index % _colors.length]
                    : AppColors.lockedDark,
              ),
            ),
            title: Text(
              unit.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              unlocked ? '×$count' : '未获得',
              style: TextStyle(
                color: unlocked
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }
}
