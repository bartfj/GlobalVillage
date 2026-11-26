import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/check_in.dart';

class CheckInFeedback extends ConsumerWidget {
  const CheckInFeedback({super.key, required this.update});

  final CheckInUpdate? update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorded = update;
    if (recorded == null || !recorded.newDay) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final day = recorded.day;
    final label =
        day == null || day == checkInDay(ref.read(checkInClockProvider)())
        ? s.checkInTodayDone
        : s.checkInRecordedFor(day.month, day.day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          for (final milestone in recorded.earned)
            Text(
              '${s.checkInMilestoneTitle(milestone.days)} · ${s.checkInTreeBonus(milestone.trees)}',
            ),
        ],
      ),
    );
  }
}
