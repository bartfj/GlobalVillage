import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/services/diagnostic_log.dart';
import 'data/models/progress.dart';
import 'data/models/user.dart';
import 'data/sources/progress_store.dart';
import 'data/sources/learning_store.dart';
import 'data/sources/reward_store.dart';
import 'data/sources/settings_store.dart';
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

class _EnglishVillageAppState extends ConsumerState<EnglishVillageApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(diagnosticUploaderProvider).flush());
    });
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(allCoursesProvider);
    return courses.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('课程加载失败：$error'))),
      ),
      data: (_) => MaterialApp.router(
        title: '地球村',
        theme: buildAppTheme(),
        routerConfig: ref.watch(goRouterProvider),
      ),
    );
  }
}
