import 'dart:io';

import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/models/user.dart';
import 'package:english_village/data/repositories/user_repository.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/data/sources/user_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late UserRepository repo;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('hive_user_test');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UserAdapter());
    }
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LessonProgressAdapter());
    }
    await Hive.openBox<User>(UserStore.usersBoxName);
    await Hive.openBox<String>(UserStore.sessionBoxName);
    await Hive.openBox<LessonProgress>(ProgressStore.boxName);
    repo = UserRepository(store: UserStore());
  });

  tearDown(() async {
    await Hive.box<User>(UserStore.usersBoxName).deleteFromDisk();
    await Hive.box<String>(UserStore.sessionBoxName).deleteFromDisk();
    await Hive.box<LessonProgress>(ProgressStore.boxName).deleteFromDisk();
    await Hive.close();
  });

  test('注册成功并建立会话', () async {
    final error = await repo.register(
      nickname: '小明',
      password: '123456',
      confirm: '123456',
    );
    expect(error, isNull);
    expect(repo.store.currentSession, '小明');
  });

  test('重复昵称注册失败', () async {
    await repo.register(nickname: '小明', password: '123456', confirm: '123456');
    final error = await repo.register(
      nickname: '小明',
      password: '654321',
      confirm: '654321',
    );
    expect(error, '该昵称已被注册');
  });

  test('短密码与确认不一致注册失败', () async {
    expect(
      await repo.register(nickname: 'aa', password: '123', confirm: '123'),
      '密码至少 6 位',
    );
    expect(
      await repo.register(nickname: 'aa', password: '123456', confirm: '1'),
      '两次输入的密码不一致',
    );
  });

  test('登录：未注册昵称与错误密码', () async {
    await repo.register(nickname: '小明', password: '123456', confirm: '123456');
    expect(await repo.login(nickname: '不存在', password: '123456'), '该昵称未注册');
    expect(await repo.login(nickname: '小明', password: 'wrong'), '密码错误');
    expect(await repo.login(nickname: '小明', password: '123456'), isNull);
  });

  test('游客会话与退出', () async {
    await repo.loginAsGuest();
    expect(repo.store.currentSession, UserRepository.guestKey);
    await repo.logout();
    expect(repo.store.currentSession, isNull);
  });

  test('会话持久化后可恢复', () async {
    await repo.register(nickname: '小明', password: '123456', confirm: '123456');
    // 模拟重启：重新读取会话
    final restored = UserStore();
    expect(restored.currentSession, '小明');
  });

  test('进度按账号隔离', () async {
    const storeA = ProgressStore(userKey: 'a');
    const storeB = ProgressStore(userKey: 'b');
    await storeA.save(const LessonProgress(
      lessonId: 'l1',
      completed: true,
      score: 80,
      correctCount: 8,
      totalCount: 10,
    ));
    expect(storeA.get('l1'), isNotNull);
    expect(storeB.get('l1'), isNull);
  });

  test('旧进度迁移到游客账号', () async {
    final box = Hive.box<LessonProgress>(ProgressStore.boxName);
    await box.put('l1', const LessonProgress(
      lessonId: 'l1',
      completed: true,
      score: 80,
      correctCount: 8,
      totalCount: 10,
    ));
    await ProgressStore.migrateLegacy();
    expect(box.get('l1'), isNull);
    expect(const ProgressStore(userKey: 'guest').get('l1'), isNotNull);
    // 幂等：再次执行不产生重复
    await ProgressStore.migrateLegacy();
    expect(box.keys.length, 1);
  });
}
