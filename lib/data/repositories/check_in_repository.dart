import '../models/check_in.dart';
import '../sources/check_in_store.dart';

class CheckInRepository {
  CheckInRepository({required this.store, this.onRecorded});

  final CheckInStore store;
  final void Function()? onRecorded;

  Future<CheckInUpdate> recordCompletion(DateTime completedAt) async {
    final day = checkInDay(completedAt);
    final key = checkInDayKey(day);
    final previous = await store.recordDay(key);
    if (previous == null) {
      return const CheckInUpdate(newDay: false, earned: []);
    }
    onRecorded?.call();
    final before = CheckInStatus.fromDays(previous, completedAt);
    final after = CheckInStatus.fromDays({...previous, key}, completedAt);
    return CheckInUpdate(
      newDay: true,
      earned: after.earned
          .where((item) => item.days > before.longestStreak)
          .toList(),
      day: day,
    );
  }
}
