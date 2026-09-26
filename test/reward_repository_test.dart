import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/repositories/reward_repository.dart';
import 'package:english_village/data/sources/reward_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Course course() => Course(
  id: 'test',
  title: 'test',
  units: List.generate(
    14,
    (i) => Unit(
      id: 'u${i + 1}',
      title: 'unit ${i + 1}',
      description: '',
      lessons: [Lesson(id: 'l${i + 1}', title: 'lesson', exercises: const [])],
    ),
  ),
);

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('reward_test');
    Hive.init(dir.path);
    await Hive.openBox<String>(RewardStore.boxName);
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'each passed attempt increments its unit and duplicate attempt is idempotent',
    () async {
      final repo = RewardRepository(
        store: const RewardStore(userKey: 'guest'),
        course: course(),
      );
      expect((await repo.awardForPassedAttempt('l1', 'a'))?.count, 1);
      expect(
        (await repo.awardForPassedAttempt('l1', 'a'))?.newlyAwarded,
        false,
      );
      expect((await repo.awardForPassedAttempt('l1', 'b'))?.count, 2);
      expect(repo.countFor('u1'), 2);
      expect(await repo.awardForPassedAttempt('unknown', 'c'), isNull);
      expect(await repo.awardForPassedAttempt('l2', 'a'), isNull);
      expect(await repo.awardForPassedAttempt('l1', ''), isNull);
    },
  );

  test(
    'all 14 units map correctly and accounts are isolated after reopening box',
    () async {
      final guest = RewardRepository(
        store: const RewardStore(userKey: 'guest'),
        course: course(),
      );
      for (var i = 1; i <= 14; i++) {
        expect(
          (await guest.awardForPassedAttempt('l$i', '$i'))?.unit.id,
          'u$i',
        );
      }
      final other = RewardRepository(
        store: const RewardStore(userKey: 'other'),
        course: course(),
      );
      expect(other.countFor('u1'), 0);
      expect((await other.awardForPassedAttempt('l1', '1'))?.count, 1);
      await Hive.box<String>(RewardStore.boxName).close();
      await Hive.openBox<String>(RewardStore.boxName);
      expect(guest.countFor('u14'), 1);
      expect(other.countFor('u1'), 1);
    },
  );
}
