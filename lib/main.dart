import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/services/diagnostic_log.dart';
import 'data/models/check_in.dart';
import 'data/models/progress.dart';
import 'data/models/user.dart';
import 'data/sources/check_in_store.dart';
import 'data/sources/progress_store.dart';
import 'data/sources/learning_store.dart';
import 'data/sources/reward_store.dart';
import 'data/sources/settings_store.dart';
import 'data/sources/skill_practice_progress_store.dart';
import 'data/sources/user_store.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Hive.initFlutter();
      Hive.registerAdapter(LessonProgressAdapter());
      Hive.registerAdapter(UserAdapter());
      await Hive.openBox<LessonProgress>(ProgressStore.boxName);
      await Hive.openBox<String>(LearningStore.boxName);
      await Hive.openBox<String>(RewardStore.boxName);
      await Hive.openBox<String>(CheckInStore.boxName);
      await Hive.openBox<String>(SkillPracticeProgressStore.boxName);
      await Hive.openBox<User>(UserStore.usersBoxName);
      await Hive.openBox<String>(UserStore.sessionBoxName);
      await Hive.openBox<String>(SettingsStore.boxName);
      await Hive.openBox<String>(DiagnosticLog.boxName);
      await ProgressStore.migrateLegacy();
      DiagnosticLog.install(DiagnosticLog());
      _hookDiagnosticErrors();
      runApp(const ProviderScope(child: EnglishVillageApp()));
    },
    (error, stack) {
      recordDiagnosticCrash('zone', error, stack);
    },
  );
}

void _hookDiagnosticErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    recordDiagnosticCrash('flutter', details.exception, details.stack);
    if (previous != null) {
      previous(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    recordDiagnosticCrash('platform', error, stack);
    return previousPlatform?.call(error, stack) ?? false;
  };
}

class EnglishVillageApp extends ConsumerStatefulWidget {
  const EnglishVillageApp({super.key});

  @override
  ConsumerState<EnglishVillageApp> createState() => _EnglishVillageAppState();
}

class _EnglishVillageAppState extends ConsumerState<EnglishVillageApp>
    with WidgetsBindingObserver {
  Timer? _checkInMidnight;
  bool _remindersDirty = false;
  bool _aligningReminders = false;
  bool _openLearningWhenReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(diagnosticUploaderProvider).flush());
      _alignForegroundSync();
      _refreshCheckInDay();
      _alignCheckInReminders();
    });
  }

  @override
  void dispose() {
    _checkInMidnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _alignForegroundSync(state);
    if (state == AppLifecycleState.resumed) {
      _refreshCheckInDay();
      _alignCheckInReminders();
    } else if (state != AppLifecycleState.inactive) {
      _checkInMidnight?.cancel();
    }
  }

  void _refreshCheckInDay() {
    if (!Hive.isBoxOpen(CheckInStore.boxName)) return;
    _checkInMidnight?.cancel();
    final now = ref.read(checkInClockProvider)();
    final midnight = checkInDay(now).add(const Duration(hours: 16));
    ref.read(checkInDayRevisionProvider.notifier).state++;
    _checkInMidnight = Timer(midnight.difference(now), _refreshCheckInDay);
  }

  void _alignCheckInReminders() {
    if (!Hive.isBoxOpen(CheckInStore.boxName)) return;
    _remindersDirty = true;
    if (!_aligningReminders) unawaited(_reconcileCheckInReminders());
  }

  Future<void> _reconcileCheckInReminders() async {
    _aligningReminders = true;
    try {
      while (mounted && _remindersDirty) {
        _remindersDirty = false;
        try {
          await ref.read(checkInRemindersReadyProvider.future);
          if (!mounted) return;
          final latest = ref.read(checkInStatusProvider)?.latestDay;
          await ref
              .read(checkInRemindersProvider)
              .reconcile(
                optedInAt: ref.read(checkInReminderOptInProvider),
                latestCheckInDay: latest == null ? null : checkInDayKey(latest),
                isEnglish: ref.read(stringsProvider).isEn,
              );
        } catch (error, stack) {
          recordDiagnosticError('check_in_reminders', error, stack);
        }
      }
    } finally {
      _aligningReminders = false;
    }
  }

  void _openLearningFromReminder() {
    if (!_openLearningWhenReady || !ref.read(allCoursesProvider).hasValue) {
      return;
    }
    _openLearningWhenReady = false;
    handleCheckInReminderTap(ref.read(goRouterProvider));
  }

  /// 前台立刻拉取并开始轮询；离开前台停止并上传未发出的变更。
  /// 下拉通知栏（inactive）不打断。待导入确认前不拉取。
  void _alignForegroundSync([AppLifecycleState? state]) {
    final lifecycle = state ?? WidgetsBinding.instance.lifecycleState;
    final sync = ref.read(syncServiceProvider);
    final pending = ref.read(authProvider).pendingImportFrom;
    if (sync == null || pending != null) {
      sync?.stopForegroundSync(flushPending: false);
      return;
    }
    if (lifecycle == AppLifecycleState.inactive) return;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.detached) {
      sync.stopForegroundSync();
      return;
    }
    sync.startForegroundSync();
  }

  /// 课程加载完成或切换轨道时，记下当前课程名，供非课时页的反馈使用。
  void _rememberCurrentCourse() {
    final courses = ref.read(allCoursesProvider).asData?.value;
    if (courses == null) return;
    final trackId = ref.read(selectedTrackProvider).id;
    for (final course in courses) {
      if (course.id != trackId) continue;
      final log = DiagnosticLog.instance;
      if (log == null) return;
      unawaited(log.rememberCourse(course.title));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authProvider.select(
        (auth) => (
          userKey: auth.userKey,
          token: auth.accessToken,
          pending: auth.pendingImportFrom,
        ),
      ),
      (previous, next) {
        _alignForegroundSync();
        if (previous?.userKey != next.userKey) _alignCheckInReminders();
      },
    );
    ref.listen(allCoursesProvider, (_, _) {
      _rememberCurrentCourse();
      _openLearningFromReminder();
    });
    ref.listen(selectedTrackProvider, (_, _) => _rememberCurrentCourse());
    ref.listen(
      checkInStatusProvider.select((status) => status?.latestDay),
      (_, _) => _alignCheckInReminders(),
    );
    ref.listen(
      checkInReminderOptInProvider,
      (_, _) => _alignCheckInReminders(),
    );
    ref.listen(uiLanguageProvider, (_, _) => _alignCheckInReminders());
    ref.listen(checkInReminderTapProvider, (_, _) {
      _openLearningWhenReady = true;
      _openLearningFromReminder();
    });
    final courses = ref.watch(allCoursesProvider);
    return courses.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('课程加载失败：$error'))),
      ),
      data: (_) {
        _rememberCurrentCourse();
        return MaterialApp.router(
          title: '地球村',
          theme: buildAppTheme(),
          routerConfig: ref.watch(goRouterProvider),
        );
      },
    );
  }
}
