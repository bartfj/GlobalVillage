import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../data/models/course_track.dart';
import '../../../data/models/tree_growth.dart';

/// 学习路径侧滑主菜单：账号头 + 进度/奖励概览 + 功能入口
class MainMenuDrawer extends ConsumerWidget {
  const MainMenuDrawer({
    super.key,
    required this.onBackupRestore,
    required this.onAbout,
    required this.onLogout,
    required this.onLogin,
  });

  final VoidCallback onBackupRestore;
  final VoidCallback onAbout;
  final VoidCallback onLogout;
  final VoidCallback onLogin;

  void _openRoute(BuildContext context, String location) {
    Navigator.of(context).pop();
    context.push(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressRevisionProvider);
    ref.watch(rewardRevisionProvider);

    final auth = ref.watch(authProvider);
    final course = ref.watch(courseProvider);
    final progress = ref.watch(progressRepositoryProvider);
    final rewards = ref.watch(rewardRepositoryProvider);
    final selectedTrack = ref.watch(selectedTrackProvider);
    final allCourses = ref.watch(allCoursesProvider).requireValue;

    if (progress == null || rewards == null) {
      return const Drawer(
        backgroundColor: Colors.white,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final total = course.orderedLessons.length;
    final completed = course.orderedLessons
        .where((l) => progress.isLessonCompleted(l.id))
        .length;
    final treeCount = rewards.treeCount;
    final treeStage = stageFor(treeCount);
    final badgeUnits = rewards.unlockedBadgeCount(allCourses);

    final isGuest = auth.isGuest;
    final displayName = isGuest ? '游客' : (auth.userKey ?? '未登录');
    final initial = displayName.isNotEmpty
        ? String.fromCharCode(displayName.runes.first)
        : '?';

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.greenLight,
                    child: isGuest
                        ? const Icon(
                            Icons.person_outline,
                            color: AppColors.greenDark,
                            size: 30,
                          )
                        : Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.greenDark,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isGuest ? '游客模式' : '本地账号',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (isGuest) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: onLogin,
                            child: const Text(
                              '注册 / 登录保存进度',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.greenDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCell(
                      label: '已通关',
                      value: '$completed/$total',
                      onTap: () => _openRoute(context, '/completed'),
                    ),
                  ),
                  Expanded(
                    child: _StatCell(
                      label: '梭梭树',
                      value: '$treeCount',
                      subtitle: treeStage.label,
                      onTap: () => _openRoute(context, '/tree'),
                    ),
                  ),
                  Expanded(
                    child: _StatCell(
                      label: '徽章',
                      value: '×$badgeUnits',
                      onTap: () => _openRoute(context, '/badges'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      '学习内容',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  for (final track in CourseTrack.values)
                    ListTile(
                      leading: Icon(
                        track == selectedTrack
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: track == selectedTrack
                            ? AppColors.green
                            : AppColors.lockedDark,
                      ),
                      title: Text(
                        track.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: track == selectedTrack
                              ? AppColors.greenDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      onTap: () async {
                        await ref
                            .read(selectedTrackProvider.notifier)
                            .select(track);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  const Divider(height: 16),
                  _MenuTile(
                    icon: Icons.sync_alt_rounded,
                    iconColor: AppColors.blue,
                    title: '备份 / 恢复',
                    onTap: onBackupRestore,
                  ),
                  _MenuTile(
                    icon: Icons.info_outline,
                    iconColor: AppColors.textSecondary,
                    title: '关于',
                    onTap: onAbout,
                  ),
                  _MenuTile(
                    icon: Icons.logout,
                    iconColor: AppColors.red,
                    title: '退出登录 / 切换账号',
                    titleColor: AppColors.red,
                    onTap: onLogout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greenDark,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.lockedDark,
      ),
      onTap: onTap,
    );
  }
}
