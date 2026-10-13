import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/backup_service.dart';
import '../core/services/phonetic_lookup_service.dart';
import '../core/services/sound_service.dart';
import '../core/services/sync_service.dart';
import '../core/services/tts_service.dart';
import '../data/models/course.dart';
import '../data/models/course_track.dart';
import '../data/repositories/course_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/reward_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/sources/cloud_auth_api.dart';
import '../data/sources/course_loader.dart';
import '../data/sources/progress_store.dart';
import '../data/sources/learning_store.dart';
import '../data/sources/reward_store.dart';
import '../data/sources/settings_store.dart';
import '../data/sources/sync_api.dart';
import '../data/sources/token_store.dart';
import '../data/sources/user_store.dart';
import 'auth_controller.dart';
import 'selected_track_controller.dart';

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

final userStoreProvider = Provider<UserStore>((ref) => UserStore());

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(userStore: ref.watch(userStoreProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(store: ref.watch(userStoreProvider)),
);

/// 在线账号 API 客户端（基址用 --dart-define=API_BASE_URL 覆盖）
final cloudAuthApiProvider = Provider<CloudAuthApi>((ref) => CloudAuthApi());

/// refresh token 安全存储
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// 进度同步 API
final syncApiProvider = Provider<SyncApi>((ref) => SyncApi());

/// 同步状态（抽屉展示）
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

/// 进度同步服务（仅在线会话启用）
// 显式声明变量类型：与 authProvider 相互引用，避免顶层类型推断循环
final Provider<SyncService?> syncServiceProvider = Provider<SyncService?>((ref) {
  final auth = ref.watch(authProvider);
  if (!auth.isOnline) return null;
  final service = SyncService(
    api: ref.watch(syncApiProvider),
    settings: ref.watch(settingsStoreProvider),
    readAuth: () => ref.read(authProvider),
    refreshAccessToken: () =>
        ref.read(authProvider.notifier).refreshAccessToken(),
    onStatus: (status) {
      ref.read(syncStatusProvider.notifier).state = status;
    },
    onMerged: () {
      ref.read(selectedTrackProvider.notifier).reload();
      ref.read(progressRevisionProvider.notifier).state++;
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

/// 认证状态（会话持久化，启动时自动恢复）
final StateNotifierProvider<AuthController, AuthState> authProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    ref.watch(userRepositoryProvider),
    cloudAuth: ref.watch(cloudAuthApiProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    onOnlineSessionReady: () =>
        ref.read(syncServiceProvider)?.pullMergePush(),
    onBoundToOnline: (fromUserKey) async {
      final sync = ref.read(syncServiceProvider);
      final toUserKey = ref.read(authProvider).userKey;
      if (sync == null || toUserKey == null) return;
      await sync.copySlot(fromUserKey, toUserKey);
      await sync.pullMergePush();
    },
  ),
);

/// 当前学习大类（按账号持久化）
final selectedTrackProvider =
    StateNotifierProvider<SelectedTrackController, CourseTrack>((ref) {
      final controller = SelectedTrackController(
        settings: ref.watch(settingsStoreProvider),
        readUserKey: () => ref.read(authProvider).userKey,
        onChanged: () => ref.read(syncServiceProvider)?.scheduleUpload(),
      );
      ref.listen<AuthState>(authProvider, (_, __) => controller.reload());
      return controller;
    });

/// 全部大类课程（启动加载一次；徽章全局展示 / 切档同步取用）
final allCoursesProvider = FutureProvider<List<Course>>(
  (ref) => CourseLoader().loadAll(),
);

/// 当前大类对应的课程（同步，依赖 allCourses 已加载）
final courseProvider = Provider<Course>((ref) {
  final track = ref.watch(selectedTrackProvider);
  final courses = ref.watch(allCoursesProvider).requireValue;
  return courses.firstWhere((c) => c.id == track.id);
});

final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(ref.watch(courseProvider)),
);

/// 无会话时返回 null，避免登出瞬间 `userKey!` 空断言崩溃
final progressStoreProvider = Provider<ProgressStore?>((ref) {
  final userKey = ref.watch(authProvider).userKey;
  if (userKey == null) return null;
  return ProgressStore(userKey: userKey);
});

final progressRepositoryProvider = Provider<ProgressRepository?>((ref) {
  final store = ref.watch(progressStoreProvider);
  if (store == null) return null;
  return ProgressRepository(
    store: store,
    course: ref.watch(courseProvider),
    onSaved: () => ref.read(syncServiceProvider)?.scheduleUpload(),
  );
});

final rewardRepositoryProvider = Provider<RewardRepository?>((ref) {
  final userKey = ref.watch(authProvider).userKey;
  if (userKey == null) return null;
  return RewardRepository(
    store: RewardStore(userKey: userKey),
    course: ref.watch(courseProvider),
    onAwarded: () => ref.read(syncServiceProvider)?.scheduleUpload(),
  );
});

final rewardRevisionProvider = StateProvider<int>((ref) => 0);

/// 进度版本号：完成课程后 +1，驱动学习路径页刷新
final progressRevisionProvider = StateProvider<int>((ref) => 0);

final learningStoreProvider = Provider<LearningStore?>((ref) {
  final userKey = ref.watch(authProvider).userKey;
  return userKey == null ? null : LearningStore(userKey: userKey);
});

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService();
  ref.onDispose(service.dispose);
  return service;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

final phoneticLookupProvider = Provider<PhoneticLookupService>((ref) {
  final service = PhoneticLookupService();
  ref.onDispose(service.dispose);
  return service;
});
