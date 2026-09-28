import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/tree_growth.dart';

/// 梭梭树成长页：展示当前阶段与累计棵数
class TreePage extends ConsumerWidget {
  const TreePage({super.key});

  static const _stageIcons = {
    TreeStage.seed: Icons.grain_rounded,
    TreeStage.sprout: Icons.eco_rounded,
    TreeStage.smallTree: Icons.park_rounded,
    TreeStage.bigTree: Icons.forest_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(rewardRevisionProvider);
    final rewards = ref.watch(rewardRepositoryProvider);
    if (rewards == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final count = rewards.treeCount;
    final stage = stageFor(count);
    final stages = TreeStage.values;
    final stageIndex = stages.indexOf(stage);
    final isMax = stageIndex >= stages.length - 1;
    final next = isMax ? null : stages[stageIndex + 1];
    final need = next == null ? 0 : (next.minTrees - count).clamp(0, 9999);

    return Scaffold(
      appBar: AppBar(title: const Text('梭梭树')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _stageIcons[stage],
                  size: 80,
                  color: AppColors.greenDark,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                stage.label,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '累计 $count 棵',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.greenDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isMax ? '已达梭梭大树' : '距「${next!.label}」还需 $need 棵',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              if (!isMax && next != null) ...[
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: next.minTrees == 0
                        ? 1
                        : (count / next.minTrees).clamp(0.0, 1.0),
                    minHeight: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
