import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/backup_service.dart';
import '../core/services/sound_service.dart';
import '../core/services/tts_service.dart';
import '../data/models/course.dart';
import '../data/repositories/course_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/reward_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/sources/course_loader.dart';
import '../data/sources/progress_store.dart';
import '../data/sources/reward_store.dart';
import '../data/sources/user_store.dart';
import 'auth_controller.dart';

/// 课程数据（启动时加载一次）
final courseProvider = FutureProvider<Course>((ref) => CourseLoader().load());

final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(ref.watch(courseProvider).requireValue),
);

final userStoreProvider = Provider<UserStore>((ref) => UserStore());

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(userStore: ref.watch(userStoreProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(store: ref.watch(userStoreProvider)),
);

/// 认证状态（会话持久化，启动时自动恢复）
final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(userRepositoryProvider)),
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
    course: ref.watch(courseProvider).requireValue,
  );
});

final rewardRepositoryProvider = Provider<RewardRepository?>((ref) {
  final userKey = ref.watch(authProvider).userKey;
  if (userKey == null) return null;
  return RewardRepository(
    store: RewardStore(userKey: userKey),
    course: ref.watch(courseProvider).requireValue,
  );
});

final rewardRevisionProvider = StateProvider<int>((ref) => 0);

/// 进度版本号：完成课程后 +1，驱动学习路径页刷新
final progressRevisionProvider = StateProvider<int>((ref) => 0);

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
