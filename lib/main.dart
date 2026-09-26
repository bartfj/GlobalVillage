import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/models/progress.dart';
import 'data/models/user.dart';
import 'data/sources/progress_store.dart';
import 'data/sources/reward_store.dart';
import 'data/sources/user_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(LessonProgressAdapter());
  Hive.registerAdapter(UserAdapter());
  await Hive.openBox<LessonProgress>(ProgressStore.boxName);
  await Hive.openBox<String>(RewardStore.boxName);
  await Hive.openBox<User>(UserStore.usersBoxName);
  await Hive.openBox<String>(UserStore.sessionBoxName);
  await ProgressStore.migrateLegacy();
  runApp(const ProviderScope(child: EnglishVillageApp()));
}

class EnglishVillageApp extends ConsumerWidget {
  const EnglishVillageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseProvider);
    return course.when(
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
