import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_strings.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/check_in.dart';

String _todayLabel(S s, CheckInStatus status) {
  if (status.checkedToday) return s.checkInTodayDone;
  if (status.streakBroken) return s.checkInRestart;
  return s.checkInTodayPending;
}

String _nextLabel(S s, CheckInStatus status) {
  final next = status.nextMilestone;
  return next == null
      ? s.checkInAllEarned
      : s.checkInUntil(next.days - status.currentStreak, next.days);
}

class CheckInHomeBanner extends ConsumerWidget {
  const CheckInHomeBanner({super.key, required this.status});

  final CheckInStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        status.checkedToday
            ? Icons.check_circle_rounded
            : Icons.local_fire_department_rounded,
        color: status.checkedToday ? AppColors.greenDark : AppColors.goldDark,
      ),
      title: Text(
        '${_todayLabel(s, status)} · ${s.checkInCurrent(status.currentStreak)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _nextLabel(s, status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/check-in'),
    );
  }
}

class CheckInPage extends ConsumerStatefulWidget {
  const CheckInPage({super.key});

  @override
  ConsumerState<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends ConsumerState<CheckInPage> {
  bool _savingReminder = false;

  Future<void> _setReminders(bool enabled) async {
    final repository = ref.read(checkInRepositoryProvider);
    if (repository == null || _savingReminder) return;
    setState(() => _savingReminder = true);
    try {
      if (enabled) {
        await ref.read(checkInRemindersReadyProvider.future);
        if (!mounted || ref.read(checkInRepositoryProvider) != repository) {
          return;
        }
        final allowed = await ref
            .read(checkInRemindersProvider)
            .requestPermission();
        if (!mounted || ref.read(checkInRepositoryProvider) != repository) {
          return;
        }
        if (!allowed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ref.read(stringsProvider).checkInPermissionHint),
            ),
          );
          return;
        }
      }
      await ref
          .read(settingsStoreProvider)
          .setCheckInReminderOptIn(
            repository.store.userKey,
            enabled ? ref.read(checkInClockProvider)() : null,
          );
      if (!mounted) return;
      ref.invalidate(checkInReminderPermissionProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).saveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final status = ref.watch(checkInStatusProvider);
    if (status == null) {
      return Scaffold(appBar: AppBar(title: Text(s.checkInTitle)));
    }
    final theme = Theme.of(context);
    final optedIn = ref.watch(checkInReminderOptInProvider) != null;
    final permission = optedIn
        ? ref.watch(checkInReminderPermissionProvider)
        : null;
    final next = status.nextMilestone;

    return Scaffold(
      appBar: AppBar(title: Text(s.checkInTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_todayLabel(s, status), style: theme.textTheme.titleMedium),
          Text(
            s.checkInCurrent(status.currentStreak),
            style: theme.textTheme.headlineMedium,
          ),
          Text(s.checkInBest(status.longestStreak)),
          const SizedBox(height: 8),
          Text(_nextLabel(s, status)),
          if (next != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: status.currentStreak / next.days),
          ],
          const SizedBox(height: 20),
          Text(s.checkInWeek, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var offset = 6; offset >= 0; offset--)
                Expanded(
                  child: _DayCell(
                    day: status.today.subtract(Duration(days: offset)),
                    status: status,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.checkInRule, style: theme.textTheme.bodySmall),
          const Divider(height: 32),
          Text(s.checkInMilestones, style: theme.textTheme.titleMedium),
          for (final milestone in CheckInMilestone.all)
            CheckInMilestoneTile(
              milestone: milestone,
              earned: status.longestStreak >= milestone.days,
            ),
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.checkInReminders),
            subtitle: Text(
              permission?.asData?.value == false
                  ? s.checkInPermissionHint
                  : s.checkInRemindersTime,
            ),
            value: optedIn,
            onChanged: _savingReminder ? null : _setReminders,
          ),
        ],
      ),
    );
  }
}

class CheckInMilestoneTile extends ConsumerWidget {
  const CheckInMilestoneTile({
    super.key,
    required this.milestone,
    required this.earned,
  });

  final CheckInMilestone milestone;
  final bool earned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        earned ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
        color: earned ? AppColors.goldDark : AppColors.textSecondary,
      ),
      title: Text(s.checkInMilestoneTitle(milestone.days)),
      subtitle: Text(s.checkInTreeBonus(milestone.trees)),
      trailing: Text(earned ? s.checkInEarned : s.checkInPending),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.status});

  final DateTime day;
  final CheckInStatus status;

  @override
  Widget build(BuildContext context) {
    final checked = status.checkedOn(day);
    final date = '${day.month}/${day.day}';
    return Semantics(
      label: date,
      checked: checked,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Icon(
              checked ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: checked ? AppColors.greenDark : AppColors.textSecondary,
            ),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
