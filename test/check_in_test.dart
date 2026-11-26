import 'dart:io';

import 'package:english_village/data/models/check_in.dart';
import 'package:english_village/data/repositories/check_in_repository.dart';
import 'package:english_village/data/sources/check_in_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('check_in_test');
    Hive.init(directory.path);
    await Hive.openBox<String>(CheckInStore.boxName);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'a concurrent merge cannot supply dates to local reward feedback',
    () async {
      const local = CheckInStore(userKey: 'guest');
      const remote = CheckInStore(userKey: 'guest');
      await local.mergeDays(['2026-11-19']);
      final repo = CheckInRepository(store: local);
      final completion = repo.recordCompletion(DateTime.utc(2026, 11, 21));
      final sync = remote.mergeDays(['2026-11-20']);

      final update = await completion;
      await sync;
      expect(update.newDay, isTrue);
      expect(update.earned, isEmpty);
      final status = CheckInStatus.fromDays(
        local.days,
        DateTime.utc(2026, 11, 21),
      );
      expect(status.bonusTrees, 1);
    },
  );

  test(
    'yesterday stays active until Beijing midnight and keeps its record',
    () {
      final days = {'2026-11-18', '2026-11-19', '2026-11-20'};
      final waiting = CheckInStatus.fromDays(
        days,
        DateTime.utc(2026, 11, 21, 15, 59),
      );
      expect(waiting.checkedToday, isFalse);
      expect(waiting.currentStreak, 3);
      final missed = CheckInStatus.fromDays(
        days,
        DateTime.utc(2026, 11, 21, 16),
      );
      expect(missed.currentStreak, 0);
      expect(missed.longestStreak, 3);
      expect(missed.bonusTrees, 1);
      expect(missed.nextMilestone?.days, 7);
    },
  );

  test('overlapping completions credit the date and milestone once', () async {
    const store = CheckInStore(userKey: 'guest');
    final repository = CheckInRepository(store: store);
    await store.mergeDays(['2026-11-19', '2026-11-20']);
    final completedAt = DateTime.utc(2026, 11, 20, 16);
    final results = await Future.wait([
      repository.recordCompletion(completedAt),
      repository.recordCompletion(completedAt),
    ]);
    expect(results.where((result) => result.newDay).length, 1);
    expect(results.expand((result) => result.earned).map((m) => m.days), [3]);
    expect(store.days, {'2026-11-19', '2026-11-20', '2026-11-21'});
    expect(const CheckInStore(userKey: 'another').days, isEmpty);
  });

  test(
    'date merging validates calendar days and retains all milestones',
    () async {
      const store = CheckInStore(userKey: 'guest');
      final first = DateTime.utc(2026, 1, 1);
      await store.mergeDays([
        for (var i = 0; i < 30; i++)
          checkInDayKey(first.add(Duration(days: i))),
        '2026-02-30',
        '2026-1-31',
      ]);
      await store.mergeDays(['2026-01-30', '2026-02-01']);
      final status = CheckInStatus.fromDays(
        store.days,
        DateTime.utc(2026, 2, 1),
      );
      expect(store.days.length, 31);
      expect(status.currentStreak, 1);
      expect(status.longestStreak, 30);
      expect(status.bonusTrees, 11);
      expect(status.nextMilestone, isNull);
    },
  );
}
