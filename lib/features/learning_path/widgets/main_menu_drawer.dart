import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/app_strings.dart';
import '../../../app/theme.dart';
import '../../../core/services/sync_service.dart';
import '../../../data/models/course_track.dart';
import '../../../data/models/learning_language.dart';
import '../../../data/models/skill_practice.dart';
import '../../../data/models/tree_growth.dart';
import '../../auth/api_base_url_dialog.dart';
import '../../auth/bind_online_sheet.dart';
import '../../skill_practice/skill_practice_style.dart';
import 'course_selector.dart';

String _uiLanguageSubtitle(WidgetRef ref, S s) {
  final override = ref.watch(uiLanguageOverrideProvider);
  return switch (override) {
    UiLanguage.chinese => '中文',
    UiLanguage.english => 'English',
    null => s.uiLanguageAuto,
  };
}

/// 界面语言选择：自动（跟随课程解释语言）/ 中文 / English
Future<void> _showUiLanguageDialog(
  BuildContext context,
  WidgetRef ref,
  S s,
) async {
  final current = ref.read(uiLanguageOverrideProvider);
  final controller = ref.read(uiLanguageOverrideProvider.notifier);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(s.uiLanguageRowTitle),
      children: [
        for (final (label, value) in [
          (s.uiLanguageAuto, null),
          ('中文', UiLanguage.chinese),
          ('English', UiLanguage.english),
        ])
          RadioListTile<UiLanguage?>(
            title: Text(label),
            value: value,
            groupValue: current,
            onChanged: (v) {
              Navigator.pop(dialogContext);
              controller.apply(v);
            },
          ),
      ],
    ),
  );
}

/// 学习路径侧滑主菜单（浅色卡片风）：账号卡 + 统计卡 + 当前学习卡 + 功能卡片
class MainMenuDrawer extends ConsumerWidget {
  const MainMenuDrawer({
    super.key,
    required this.onBackupRestore,
    required this.onFeedback,
    required this.onAbout,
    required this.onLogout,
    required this.onLogin,
  });

  final VoidCallback onBackupRestore;
  final VoidCallback onFeedback;
  final VoidCallback onAbout;
  final VoidCallback onLogout;
  final VoidCallback onLogin;

  static const _background = Color(0xFFF5F8F4);

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
    final s = ref.watch(stringsProvider);

    if (progress == null || rewards == null) {
      return const Drawer(
        backgroundColor: _background,
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
    final displayName = isGuest
        ? s.guest
        : auth.isOnline
            ? (auth.displayName ?? s.onlineUser)
            : (auth.userKey ?? s.notLoggedIn);
    final initial = displayName.isNotEmpty
        ? String.fromCharCode(displayName.runes.first)
        : '?';

    final tracksOfLanguage = CourseTrack.values
        .where((t) => t.language == selectedTrack.language)
        .toList();

    return Drawer(
      backgroundColor: _background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          children: [
            _AccountCard(
              displayName: displayName,
              initial: initial,
              isGuest: isGuest,
              isOnline: auth.isOnline,
              userKey: auth.userKey,
              s: s,
              onLogin: onLogin,
              onOpen: isGuest ? null : () => _openRoute(context, '/account'),
            ),
            const SizedBox(height: 10),
            _StatsCard(
              cells: [
                _StatData(
                  icon: Icons.flag_rounded,
                  color: AppColors.blue,
                  label: s.statsCompleted,
                  value: '$completed/$total',
                  onTap: () => _openRoute(context, '/completed'),
                ),
                _StatData(
                  icon: Icons.park_rounded,
                  color: AppColors.greenDark,
                  label: s.statsTree,
                  value: '$treeCount',
                  subtitle: treeStage.label,
                  onTap: () => _openRoute(context, '/tree'),
                ),
                _StatData(
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.goldDark,
                  label: s.statsBadges,
                  value: '×$badgeUnits',
                  onTap: () => _openRoute(context, '/badges'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _CurrentCourseCard(
              title: s.isEn
                  ? s.languageLabel(selectedTrack.language)
                  : selectedTrack.language.shortLabel,
              completed: completed,
              total: total,
              switchLabel: s.switchCourse,
              completedText: s.completedCount(completed, total),
              onTap: () => showCourseSelector(context, ref),
            ),
            // 多课程语言（英语）显示等级快捷切换；单课程语言摘要卡已足够
            if (tracksOfLanguage.length > 1) ...[
              const SizedBox(height: 10),
              _SectionCard(
                title: s.sectionCourses,
                child: Column(
                  children: [
                    for (final track in tracksOfLanguage)
                      _CourseRow(
                        label: s.trackLabel(track),
                        selected: track == selectedTrack,
                        onTap: () async {
                          await ref
                              .read(selectedTrackProvider.notifier)
                              .select(track);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            // 专项练习按当前学习语言显示；梵文另有参考录音入口
            _SectionCard(
              title: s.sectionPractice,
              child: Column(
                children: [
                  if (selectedTrack.language == LearningLanguage.sanskrit)
                    _MenuRow(
                      icon: Icons.record_voice_over_rounded,
                      color: AppColors.goldDark,
                      title: s.sanskritAudioTitle,
                      subtitle: s.sanskritAudioSubtitle,
                      onTap: () => _openRoute(context, '/sanskrit-audio'),
                    ),
                  for (final skill in SkillPracticeKind.forLanguage(
                    selectedTrack.language,
                  ))
                    _MenuRow(
                      icon: skill.icon,
                      color: skill.accent,
                      title: s.skillTitle(skill),
                      onTap: () => _openRoute(context, '/practice/${skill.name}'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _SectionCard(
              title: s.sectionMore,
              child: Column(
                children: [
                  _MenuRow(
                    icon: Icons.history_rounded,
                    color: AppColors.blue,
                    title: s.reviewRecords,
                    onTap: () => _openRoute(context, '/review'),
                  ),
                  _MenuRow(
                    icon: Icons.translate_rounded,
                    color: AppColors.greenDark,
                    title: s.uiLanguageRowTitle,
                    subtitle: _uiLanguageSubtitle(ref, s),
                    onTap: () => _showUiLanguageDialog(context, ref, s),
                  ),
                  _MenuRow(
                    icon: Icons.dns_outlined,
                    color: AppColors.blue,
                    title: s.serverUrl,
                    subtitle: ref.watch(apiBaseUrlProvider),
                    onTap: () => showApiBaseUrlDialog(context),
                  ),
                  _MenuRow(
                    icon: Icons.sync_alt_rounded,
                    color: AppColors.blueDark,
                    title: s.backupRestore,
                    onTap: onBackupRestore,
                  ),
                  _MenuRow(
                    icon: Icons.feedback_outlined,
                    color: AppColors.textSecondary,
                    title: s.feedbackRow,
                    onTap: onFeedback,
                  ),
                  _MenuRow(
                    icon: Icons.info_outline_rounded,
                    color: AppColors.textSecondary,
                    title: s.about,
                    onTap: onAbout,
                  ),
                  _MenuRow(
                    icon: Icons.logout_rounded,
                    color: AppColors.red,
                    title: s.logoutSwitch,
                    titleColor: AppColors.red,
                    showChevron: false,
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

/// 卡片容器：白底圆角 16 + 浅阴影
class _Card extends StatelessWidget {
  const _Card({required this.child, this.color, this.padding});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    );
  }
}

/// 分区卡：卡内顶部小标题 + 内容
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

/// 账号卡：头像 + 昵称 + 账号类型 chip + 状态操作行
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.displayName,
    required this.initial,
    required this.isGuest,
    required this.isOnline,
    required this.userKey,
    required this.s,
    required this.onLogin,
    this.onOpen,
  });

  final String displayName;
  final String initial;
  final bool isGuest;
  final bool isOnline;
  final String? userKey;
  final S s;
  final VoidCallback onLogin;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final (chipLabel, chipColor) = isGuest
        ? (s.chipGuest, AppColors.textSecondary)
        : isOnline
            ? (s.chipOnline, AppColors.blue)
            : (s.chipLocal, AppColors.goldDark);
    final card = _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.greenLight,
                child: isGuest
                    ? const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.greenDark,
                        size: 28,
                      )
                    : Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppColors.greenDark,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        chipLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: chipColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isGuest) ...[
            const SizedBox(height: 10),
            _LinkRow(
              icon: Icons.login_rounded,
              text: s.registerLoginCta,
              color: AppColors.greenDark,
              onTap: onLogin,
            ),
          ] else if (!isOnline) ...[
            const SizedBox(height: 10),
            _LinkRow(
              icon: Icons.cloud_upload_outlined,
              text: s.bindOnlineCta,
              color: AppColors.blue,
              onTap: () => showBindOnlineSheet(context),
            ),
          ] else if (userKey != null) ...[
            const SizedBox(height: 10),
            _SyncStatusLine(userKey: userKey!),
          ],
        ],
      ),
    );
    if (onOpen == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: card,
      ),
    );
  }
}

/// 状态/操作小链接行
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 统计卡：三列图标统计
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.cells});

  final List<_StatData> cells;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          for (final cell in cells)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: cell.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: cell.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(cell.icon, size: 19, color: cell.color),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cell.value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        cell.subtitle == null
                            ? cell.label
                            : '${cell.label} · ${cell.subtitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatData {
  const _StatData({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;
}

/// 当前学习卡（浅绿高亮）：语言·课程 + 进度条 + 切换
class _CurrentCourseCard extends StatelessWidget {
  const _CurrentCourseCard({
    required this.title,
    required this.completed,
    required this.total,
    required this.switchLabel,
    required this.completedText,
    required this.onTap,
  });

  final String title;
  final int completed;
  final int total;
  final String switchLabel;
  final String completedText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    return _Card(
      color: AppColors.greenLight.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.language_rounded,
                    size: 20,
                    color: AppColors.greenDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.greenDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          switchLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.greenDark,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.greenDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: Colors.white,
                  valueColor: const AlwaysStoppedAnimation(AppColors.green),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                completedText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 系统课程行：选中圆点 + 课程名
class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 22,
              color: selected ? AppColors.green : AppColors.lockedDark,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.greenDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 功能菜单行：彩色圆角图标 + 标题 + chevron
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.titleColor,
    this.showChevron = true,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.lockedDark,
              ),
          ],
        ),
      ),
    );
  }
}

/// 在线账号的同步状态行：同步中 / 上次同步时间 / 同步失败
class _SyncStatusLine extends ConsumerWidget {
  const _SyncStatusLine({required this.userKey});

  final String userKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final status = ref.watch(syncStatusProvider);
    final lastSyncAt = ref.watch(settingsStoreProvider).lastSyncAt(userKey);
    final (text, color) = switch (status) {
      SyncStatus.syncing => (s.syncNow, AppColors.textSecondary),
      SyncStatus.failed => (s.syncFailed, AppColors.textSecondary),
      _ when lastSyncAt != null => (
        s.syncLastAt(_format(lastSyncAt)),
        AppColors.textSecondary,
      ),
      _ => (s.syncWaiting, AppColors.textSecondary),
    };
    return Row(
      children: [
        Icon(Icons.sync_rounded, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  String _format(int milliseconds) {
    final t = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
