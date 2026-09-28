import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/backup_service.dart';
import '../core/services/sound_service.dart';
import '../core/services/tts_service.dart';
import '../data/models/course.dart';
import '../data/models/course_track.dart';
import '../data/repositories/course_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/reward_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/sources/course_loader.dart';
import '../data/sources/progress_store.dart';
import '../data/sources/reward_store.dart';
import '../data/sources/settings_store.dart';
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

/// 认证状态（会话持久化，启动时自动恢复）
final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(userRepositoryProvider)),
);

/// 当前学习大类（按账号持久化）
final selectedTrackProvider =
    StateNotifierProvider<SelectedTrackController, CourseTrack>((ref) {
      final controller = SelectedTrackController(
        settings: ref.watch(settingsStoreProvider),
        readUserKey: () => ref.read(authProvider).userKey,
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

final progressStoreProvider = Provider<ProgressStore>(
  (ref) => ProgressStore(userKey: ref.watch(authProvider).userKey!),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(
    store: ref.watch(progressStoreProvider),
    course: ref.watch(courseProvider),
  ),
);

final rewardRepositoryProvider = Provider<RewardRepository>(
  (ref) => RewardRepository(
    store: RewardStore(userKey: ref.watch(authProvider).userKey!),
    course: ref.watch(courseProvider),
  ),
);

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
