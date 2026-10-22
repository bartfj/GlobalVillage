import 'dart:io';

import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/core/constants.dart';
import 'package:english_village/core/services/sync_service.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/models/user.dart';
import 'package:english_village/data/repositories/user_repository.dart';
import 'package:english_village/data/sources/cloud_auth_api.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/data/sources/reward_store.dart';
import 'package:english_village/data/sources/settings_store.dart';
import 'package:english_village/data/sources/sync_api.dart';
import 'package:english_village/data/sources/token_store.dart';
import 'package:english_village/data/sources/user_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

LessonProgress _lesson(
  String id, {
  required bool completed,
  int score = 0,
  int correctCount = 0,
  int totalCount = 9,
  int completedAtMs = 0,
}) =>
    LessonProgress(
      lessonId: id,
      completed: completed,
      score: score,
      correctCount: correctCount,
      totalCount: totalCount,
      completedAt: completedAtMs == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(completedAtMs),
    );

class _FakeSyncApi extends SyncApi {
  RemoteSnapshot? remote;
  Map<String, dynamic>? pushedPayload;
  Map<String, dynamic>? pushedDevice;
  int? pushedBase;
  int pullCalls = 0;
  int pushCalls = 0;

  @override
  Future<RemoteSnapshot?> pull(String accessToken) async {
    pullCalls++;
    return remote;
  }

  @override
  Future<void> push(
    String accessToken,
    Map<String, dynamic> payload,
    int clientUpdatedAt, {
    int? baseClientUpdatedAt,
    Map<String, dynamic>? device,
  }) async {
    pushCalls++;
    pushedPayload = payload;
    pushedBase = baseClientUpdatedAt;
    pushedDevice = device;
  }
}

class _FakeCloudAuth extends CloudAuthApi {
  @override
  Future<OnlineAuthResult> register({
    String? email,
    String? phone,
    required String password,
    String? displayName,
  }) async =>
      OnlineAuthResult(
        account: OnlineAccount(
          accountId: 'acc-1',
          email: email,
          phone: phone,
          displayName: 'ann',
        ),
        accessToken: 'at',
        refreshToken: 'rt',
      );

  @override
  Future<OnlineAuthResult> login({
    String? email,
    String? phone,
    required String password,
  }) async =>
      register(email: email, phone: phone, password: password);
}

void main() {
  group('SyncMerger 合并规则', () {
    test('完成优先：一侧完成一侧未完成保留完成', () {
      final merged = SyncMerger.mergeLesson(
        _lesson('l1', completed: false, correctCount: 5),
        _lesson('l1', completed: true, score: 70, completedAtMs: 100),
      );
      expect(merged.completed, isTrue);
      expect(merged.score, 70);
    });

    test('双完成取高分，同分取较新 completedAt', () {
      final higher = SyncMerger.mergeLesson(
        _lesson('l1', completed: true, score: 80, completedAtMs: 100),
        _lesson('l1', completed: true, score: 90, completedAtMs: 50),
      );
      expect(higher.score, 90);
      final newer = SyncMerger.mergeLesson(
        _lesson('l1', completed: true, score: 90, completedAtMs: 200),
        _lesson('l1', completed: true, score: 90, completedAtMs: 50),
      );
      expect(newer.completedAt!.millisecondsSinceEpoch, 200);
    });

    test('双未完成取正确数较多者', () {
      final merged = SyncMerger.mergeLesson(
        _lesson('l1', completed: false, correctCount: 3),
        _lesson('l1', completed: false, correctCount: 6),
      );
      expect(merged.correctCount, 6);
    });

    test('奖励 attemptId 并集', () {
      final merged = SyncMerger.mergeRewards(
        {'a1': 'l1', 'a2': 'l2'},
        {'a2': 'l2', 'a3': 'l3'},
      );
      expect(merged.keys, containsAll(['a1', 'a2', 'a3']));
    });

    test('轨道取 updatedAt 较新一侧', () {
      final merged = SyncMerger.mergeTrack(
        {'selected': 'zero', 'updatedAt': 100},
        {'selected': 'beginner', 'updatedAt': 200},
      );
      expect(merged['selected'], 'beginner');
    });

    test('快照序列化往返', () {
      final snapshot = SyncSnapshot(
        progress: {'l1': _lesson('l1', completed: true, score: 90, completedAtMs: 100)},
        rewards: {'a1': 'l1'},
        track: const {'selected': 'zero', 'updatedAt': 100},
        clientUpdatedAt: 100,
      );
      final restored = SyncSnapshot.fromPayload(snapshot.toPayload());
      expect(restored.progress['l1']!.completed, isTrue);
      expect(restored.progress['l1']!.score, 90);
      expect(
          restored.progress['l1']!.completedAt!.millisecondsSinceEpoch, 100);
      expect(restored.rewards, {'a1': 'l1'});
      expect(restored.track['selected'], 'zero');
    });
  });

  group('SyncService（Hive 集成）', () {
    late SettingsStore settings;
    late _FakeSyncApi api;
    late SyncService service;
    late AuthController auth;
    const userKey = 'online:acc-1';

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('hive_sync_test');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(LessonProgressAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UserAdapter());
      }
      await Hive.openBox<LessonProgress>(ProgressStore.boxName);
      await Hive.openBox<String>(RewardStore.boxName);
      await Hive.openBox<String>(SettingsStore.boxName);
      await Hive.openBox<User>(UserStore.usersBoxName);
      await Hive.openBox<String>(UserStore.sessionBoxName);
      settings = SettingsStore();
      api = _FakeSyncApi();
      auth = AuthController(
        UserRepository(store: UserStore()),
        cloudAuth: _FakeCloudAuth(),
        tokenStore: MemoryTokenStore(),
      );
      await auth.registerOnline(
        email: 'a@example.com',
        displayName: 'ann',
        password: 'secret6',
        confirm: 'secret6',
      );
      service = SyncService(
        api: api,
        settings: settings,
        readAuth: () => auth.state,
        refreshAccessToken: () async => true,
        debounce: const Duration(milliseconds: 10),
      );
    });

    tearDown(() async {
      service.dispose();
      auth.dispose();
      await Hive.box<LessonProgress>(ProgressStore.boxName).deleteFromDisk();
      await Hive.box<String>(RewardStore.boxName).deleteFromDisk();
      await Hive.box<String>(SettingsStore.boxName).deleteFromDisk();
      await Hive.box<User>(UserStore.usersBoxName).deleteFromDisk();
      await Hive.box<String>(UserStore.sessionBoxName).deleteFromDisk();
      await Hive.close();
    });

    test('云端无快照：首次同步直接上传本地', () async {
      await ProgressStore(userKey: userKey).save(
          _lesson('l1', completed: true, score: 80, completedAtMs: 100));
      await service.pullMergePush();
      expect(api.pullCalls, 1);
      expect(api.pushCalls, 1);
      expect(api.pushedBase, isNull);
      final pushed = SyncSnapshot.fromPayload(api.pushedPayload!);
      expect(pushed.progress['l1']!.completed, isTrue);
      expect(settings.lastSyncAt(userKey), isNotNull);
    });

    test('上传附带设备信息，安装 ID 与本地一致', () async {
      await service.pullMergePush();
      final device = api.pushedDevice!;
      expect(device['platform'], isNotEmpty);
      expect(device['appVersion'], kAppVersion);
      expect(device['installId'], await settings.ensureInstallId());
    });

    test('拉取合并：云端已完成的课写入本地并回传并集', () async {
      api.remote = RemoteSnapshot(
        clientUpdatedAt: 500,
        payload: SyncSnapshot(
          progress: {
            'l1': _lesson('l1', completed: true, score: 90, completedAtMs: 400),
            'l2': _lesson('l2', completed: true, score: 60, completedAtMs: 300),
          },
          rewards: const {'a1': 'l1'},
          track: const {'selected': 'beginner', 'updatedAt': 500},
          clientUpdatedAt: 500,
        ).toPayload(),
      );
      await ProgressStore(userKey: userKey).save(
          _lesson('l1', completed: false, correctCount: 4));
      await RewardStore(userKey: userKey).save('a2', 'l3');
      await settings.setTrack(userKey, CourseTrack.zero);

      await service.pullMergePush();

      // 本地已写入云端完成记录与奖励
      final local = ProgressStore(userKey: userKey).entries;
      expect(local['l1']!.completed, isTrue);
      expect(local['l1']!.score, 90);
      expect(local['l2']!.completed, isTrue);
      expect(RewardStore(userKey: userKey).attempts.keys,
          containsAll(['a1', 'a2']));
      // 上传并集，乐观锁带上云端版本
      expect(api.pushedBase, 500);
      final pushed = SyncSnapshot.fromPayload(api.pushedPayload!);
      expect(pushed.progress.keys, containsAll(['l1', 'l2']));
      expect(pushed.rewards.keys, containsAll(['a1', 'a2']));
    });

    test('scheduleUpload 防抖后自动上传', () async {
      await ProgressStore(userKey: userKey).save(
          _lesson('l1', completed: true, score: 80, completedAtMs: 100));
      service.scheduleUpload();
      expect(api.pushCalls, 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.pushCalls, greaterThan(0));
    });

    test('copySlot 复制进度/奖励/轨道且保留源槽位', () async {
      await ProgressStore(userKey: 'alice').save(
          _lesson('l1', completed: true, score: 80, completedAtMs: 100));
      await RewardStore(userKey: 'alice').save('a1', 'l1');
      await settings.setTrack('alice', CourseTrack.intermediate);
      await service.copySlot('alice', userKey);
      expect(
          ProgressStore(userKey: userKey).entries['l1']!.completed, isTrue);
      expect(RewardStore(userKey: userKey).attempts, {'a1': 'l1'});
      expect(settings.getTrack(userKey), CourseTrack.intermediate);
      // 源槽位保留
      expect(ProgressStore(userKey: 'alice').entries['l1']!.completed, isTrue);
    });

    test('本地账号绑定在线：会话切换、标记绑定、回调迁移', () async {
      await UserStore().putUser(User(
        nickname: 'alice',
        passwordHash: 'h',
        salt: 's',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      ));
      await UserStore().setSession('alice');
      String? migratedFrom;
      final bound = AuthController(
        UserRepository(store: UserStore()),
        cloudAuth: _FakeCloudAuth(),
        tokenStore: MemoryTokenStore(),
        onBoundToOnline: (from, to) async => migratedFrom = from,
      );
      addTearDown(bound.dispose);
      // 先恢复为本地会话
      expect(bound.state.userKey, 'alice');
      final error = await bound.registerAndBind(
        email: 'a@example.com',
        password: 'secret6',
      );
      expect(error, isNull);
      expect(bound.state.userKey, 'online:acc-1');
      expect(migratedFrom, 'alice');
      expect(UserStore().getUser('alice')!.onlineAccountId, 'acc-1');
      // 原本地槽位保留（只读副本）
      expect(UserStore().getUser('alice'), isNotNull);
    });

    test('游客升级为在线：标记待导入，确认后清除', () async {
      await UserStore().setSession(UserRepository.guestKey);
      await ProgressStore(userKey: UserRepository.guestKey).save(
          _lesson('l1', completed: true, score: 80, completedAtMs: 100));
      final guest = AuthController(
        UserRepository(store: UserStore()),
        cloudAuth: _FakeCloudAuth(),
        tokenStore: MemoryTokenStore(),
      );
      addTearDown(guest.dispose);
      expect(guest.state.isGuest, isTrue);
      final error = await guest.registerOnline(
        email: 'a@example.com',
        displayName: 'ann',
        password: 'secret6',
        confirm: 'secret6',
      );
      expect(error, isNull);
      expect(guest.state.pendingImportFrom, UserRepository.guestKey);
      guest.clearPendingImport();
      expect(guest.state.pendingImportFrom, isNull);
    });

    test('绑定先复制本地进度，再开始同步', () async {
      await UserStore().putUser(User(
        nickname: 'alice',
        passwordHash: 'h',
        salt: 's',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      ));
      await ProgressStore(userKey: 'alice').save(
          _lesson('l1', completed: true, score: 80, completedAtMs: 100));
      await UserStore().setSession('alice');
      final events = <String>[];
      late AuthController bound;
      bound = AuthController(
        UserRepository(store: UserStore()),
        cloudAuth: _FakeCloudAuth(),
        tokenStore: MemoryTokenStore(),
        onOnlineSessionReady: () {
          events.add('sync');
          expect(
            ProgressStore(userKey: 'online:acc-1').entries['l1']?.completed,
            isTrue,
          );
        },
        onBoundToOnline: (from, to) async {
          events.add('copy');
          expect(from, 'alice');
          expect(to, 'online:acc-1');
          await SyncService(
            api: _FakeSyncApi(),
            settings: SettingsStore(),
            readAuth: () => bound.state,
            refreshAccessToken: () async => false,
          ).copySlot(from, to);
        },
      );
      addTearDown(bound.dispose);
      final error = await bound.loginAndBind(
        email: 'a@example.com',
        password: 'secret6',
      );
      expect(error, isNull);
      expect(events, ['copy', 'sync']);
    });

    test('退出本地账号后登录在线，待导入该账号且先不同步', () async {
      await UserStore().putUser(User(
        nickname: 'alice',
        passwordHash: 'h',
        salt: 's',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      ));
      await ProgressStore(userKey: 'alice').save(
          _lesson('l1', completed: true, score: 80, completedAtMs: 100));
      await UserStore().setSession('alice');
      var syncs = 0;
      final auth = AuthController(
        UserRepository(store: UserStore()),
        cloudAuth: _FakeCloudAuth(),
        tokenStore: MemoryTokenStore(),
        onOnlineSessionReady: () => syncs++,
      );
      addTearDown(auth.dispose);
      expect(auth.state.userKey, 'alice');
      await auth.logout();
      final error = await auth.loginOnline(
        email: 'a@example.com',
        password: 'secret6',
      );
      expect(error, isNull);
      expect(auth.state.pendingImportFrom, 'alice');
      expect(syncs, 0);
    });

    test('未退出记录时，在线登录仍发现本机本地进度', () async {
      await UserStore().putUser(User(
        nickname: 'alice',
        passwordHash: 'h',
        salt: 's',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      ));
      await ProgressStore(userKey: 'alice').save(
          _lesson('l1', completed: true, score: 80, completedAtMs: 100));
      await UserStore().clearSession();
      var syncs = 0;
      final auth = AuthController(
        UserRepository(store: UserStore()),
        cloudAuth: _FakeCloudAuth(),
        tokenStore: MemoryTokenStore(),
        onOnlineSessionReady: () => syncs++,
      );
      addTearDown(auth.dispose);
      final error = await auth.loginOnline(
        email: 'a@example.com',
        password: 'secret6',
      );
      expect(error, isNull);
      expect(auth.localAccountsToImport(), ['alice']);
      expect(auth.state.pendingImportFrom, 'alice');
      expect(syncs, 0);
    });

    test('已绑定但在线槽位缺少进度时仍可导入', () async {
      await UserStore().putUser(User(
        nickname: 'alice',
        passwordHash: 'h',
        salt: 's',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        onlineAccountId: 'acc-1',
        onlineBoundAt: 1,
      ));
      await ProgressStore(userKey: 'alice').save(
          _lesson('l1', completed: true, score: 80, completedAtMs: 100));
      final auth = AuthController(
        UserRepository(store: UserStore()),
        cloudAuth: _FakeCloudAuth(),
        tokenStore: MemoryTokenStore(),
      );
      addTearDown(auth.dispose);
      expect(auth.state.userKey, 'online:acc-1');
      expect(auth.localAccountsToImport(), ['alice']);
    });

    test('本机可重设本地账号密码', () async {
      final repo = UserRepository(store: UserStore());
      final auth = AuthController(
        repo,
        cloudAuth: _FakeCloudAuth(),
        tokenStore: MemoryTokenStore(),
      );
      addTearDown(auth.dispose);
      await UserStore().clearSession();
      expect(
        await repo.register(
          nickname: 'bob',
          password: 'secret6',
          confirm: 'secret6',
        ),
        isNull,
      );
      expect(
        await auth.resetLocalPassword(
          nickname: 'bob',
          password: 'newpass',
          confirm: 'newpass',
        ),
        isNull,
      );
      expect(await auth.login(nickname: 'bob', password: 'secret6'), '密码错误');
      expect(await auth.login(nickname: 'bob', password: 'newpass'), isNull);
    });
  });
}
