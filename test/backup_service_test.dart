import 'dart:convert';
import 'dart:io';

import 'package:english_village/core/services/backup_service.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/models/user.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/data/sources/reward_store.dart';
import 'package:english_village/data/sources/user_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  // TypeAdapter 全局注册，只能注册一次
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(LessonProgressAdapter());

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_test');
    Hive.init(tempDir.path);
    await Hive.openBox<User>(UserStore.usersBoxName);
    await Hive.openBox<String>(UserStore.sessionBoxName);
    await Hive.openBox<LessonProgress>(ProgressStore.boxName);
    await Hive.openBox<String>(RewardStore.boxName);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('备份导出/导入 round-trip 恢复账号、进度与会话', () async {
    final store = UserStore();
    final service = BackupService(userStore: store);

    // 准备账号与进度
    await store.putUser(
      User(
        nickname: 'tester',
        passwordHash: 'hash123',
        salt: 'salt123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      ),
    );
    await store.setSession('tester');
    final progressBox = Hive.box<LessonProgress>(ProgressStore.boxName);
    await progressBox.put(
      'tester|u1l1',
      LessonProgress(
        lessonId: 'u1l1',
        completed: true,
        score: 80,
        correctCount: 7,
        totalCount: 8,
        completedAt: DateTime.fromMillisecondsSinceEpoch(1700000100000),
      ),
    );
    await progressBox.put(
      'tester|u1l2',
      const LessonProgress(
        lessonId: 'u1l2',
        completed: false,
        score: 0,
        correctCount: 0,
        totalCount: 8,
      ),
    );
    // 其他账号进度不应被导出
    await progressBox.put(
      'other|u1l1',
      const LessonProgress(
        lessonId: 'u1l1',
        completed: true,
        score: 10,
        correctCount: 1,
        totalCount: 8,
      ),
    );

    final code = await service.exportBackup();
    expect(code, isNotNull);
    expect((jsonDecode(code!) as Map<String, dynamic>)['version'], 2);

    // 模拟换机：清空全部 box
    await Hive.box<User>(UserStore.usersBoxName).clear();
    await Hive.box<String>(UserStore.sessionBoxName).clear();
    await Hive.box<LessonProgress>(ProgressStore.boxName).clear();
    expect(store.currentSession, isNull);

    // 导入恢复
    final error = await service.importBackup(code);
    expect(error, isNull);

    final user = store.getUser('tester');
    expect(user, isNotNull);
    expect(user!.passwordHash, 'hash123');
    expect(user.salt, 'salt123');
    expect(store.currentSession, 'tester');

    final p1 = progressBox.get('tester|u1l1');
    expect(p1, isNotNull);
    expect(p1!.completed, isTrue);
    expect(p1.score, 80);
    expect(p1.completedAt!.millisecondsSinceEpoch, 1700000100000);
    final p2 = progressBox.get('tester|u1l2');
    expect(p2, isNotNull);
    expect(p2!.completed, isFalse);
    // 其他账号进度未被导入
    expect(progressBox.get('other|u1l1'), isNull);
  });

  test('游客会话导出返回 null', () async {
    final store = UserStore();
    final service = BackupService(userStore: store);
    await store.setSession('guest');
    expect(await service.exportBackup(), isNull);
  });

  test('非法备份码返回错误文案', () async {
    final store = UserStore();
    final service = BackupService(userStore: store);
    expect(await service.importBackup('not json'), '备份码格式错误，无法解析');
    expect(await service.importBackup('{"version":3}'), '不支持的备份码版本');
    expect(await service.importBackup('{"version":1}'), '备份码缺少账号信息');
  });

  test(
    'v2 rewards round-trip, repeated import merges, and account isolation',
    () async {
      final users = UserStore();
      final service = BackupService(userStore: users);
      await users.putUser(
        User(
          nickname: 'tester',
          passwordHash: 'hash',
          salt: 'salt',
          createdAt: DateTime(2025),
        ),
      );
      await users.setSession('tester');
      await const RewardStore(userKey: 'tester').save('a1', 'u1');
      await const RewardStore(userKey: 'other').save('b1', 'u2');
      final code = (await service.exportBackup())!;
      final backup = jsonDecode(code) as Map<String, dynamic>;
      expect(backup['rewards'], [
        {'attemptId': 'a1', 'unitId': 'u1'},
      ]);
      await Hive.box<String>(RewardStore.boxName).clear();
      expect(await service.importBackup(code), isNull);
      expect(await service.importBackup(code), isNull);
      expect(const RewardStore(userKey: 'tester').attempts, {'a1': 'u1'});
      expect(const RewardStore(userKey: 'other').attempts, isEmpty);
    },
  );

  test(
    'v1 backup restores progress without rewards; invalid v2 rewards rejected before writing',
    () async {
      final users = UserStore();
      final service = BackupService(userStore: users);
      await users.putUser(
        User(
          nickname: 'tester',
          passwordHash: 'hash',
          salt: 'salt',
          createdAt: DateTime(2025),
        ),
      );
      await users.setSession('tester');
      final data =
          jsonDecode((await service.exportBackup())!) as Map<String, dynamic>;
      data['version'] = 1;
      data.remove('rewards');
      await Hive.box<User>(UserStore.usersBoxName).clear();
      await Hive.box<String>(UserStore.sessionBoxName).clear();
      expect(await service.importBackup(jsonEncode(data)), isNull);
      expect(users.currentSession, 'tester');
      expect(const RewardStore(userKey: 'tester').attempts, isEmpty);

      data['version'] = 2;
      data['rewards'] = [
        {'attemptId': 'a', 'unitId': 'u1'},
        {'attemptId': 'a', 'unitId': 'u2'},
      ];
      await Hive.box<User>(UserStore.usersBoxName).clear();
      expect(await service.importBackup(jsonEncode(data)), '备份码收藏数据错误');
      expect(users.getUser('tester'), isNull);
    },
  );
}
