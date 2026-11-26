/// The calendar date in Beijing, represented at UTC midnight for date arithmetic.
DateTime checkInDay(DateTime instant) {
  final beijing = instant.toUtc().add(const Duration(hours: 8));
  return DateTime.utc(beijing.year, beijing.month, beijing.day);
}

String checkInDayKey(DateTime day) => day.toIso8601String().split('T').first;

DateTime? parseCheckInDay(String value) {
  if (value.length != 10) return null;
  final day = DateTime.tryParse('${value}T00:00:00Z');
  return day != null && day.year >= 1 && checkInDayKey(day) == value
      ? day
      : null;
}

class CheckInMilestone {
  const CheckInMilestone(this.days, this.trees);

  final int days;
  final int trees;

  static const all = [
    CheckInMilestone(3, 1),
    CheckInMilestone(7, 2),
    CheckInMilestone(14, 3),
    CheckInMilestone(30, 5),
  ];
}

class CheckInStatus {
  CheckInStatus.fromDays(Set<String> days, DateTime now)
    : today = checkInDay(now),
      _days = Set.unmodifiable(days) {
    final ordered = days.toList()..sort();
    DateTime? previous;
    var run = 0;
    var longest = 0;
    var current = 0;
    DateTime? latest;
    for (final key in ordered) {
      final day = parseCheckInDay(key);
      if (day == null) continue;
      run = previous != null && day.difference(previous).inDays == 1
          ? run + 1
          : 1;
      if (run > longest) longest = run;
      if (!day.isAfter(today)) {
        latest = day;
        current = today.difference(day).inDays <= 1 ? run : 0;
      }
      previous = day;
    }
    longestStreak = longest;
    currentStreak = current;
    latestDay = latest;
  }

  final DateTime today;
  final Set<String> _days;
  late final int currentStreak;
  late final int longestStreak;
  late final DateTime? latestDay;

  bool checkedOn(DateTime day) => _days.contains(checkInDayKey(day));
  bool get checkedToday => checkedOn(today);
  bool get streakBroken => latestDay != null && currentStreak == 0;

  Iterable<CheckInMilestone> get earned => CheckInMilestone.all.where(
    (milestone) => milestone.days <= longestStreak,
  );

  CheckInMilestone? get nextMilestone => CheckInMilestone.all
      .where((milestone) => milestone.days > longestStreak)
      .firstOrNull;

  int get bonusTrees =>
      earned.fold(0, (total, milestone) => total + milestone.trees);
}

class CheckInUpdate {
  const CheckInUpdate({required this.newDay, required this.earned, this.day});

  final bool newDay;
  final List<CheckInMilestone> earned;
  final DateTime? day;
}
