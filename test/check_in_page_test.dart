import 'dart:async';
import 'dart:io';

import 'package:english_village/app/providers.dart';
import 'package:english_village/app/router.dart';
import 'package:english_village/data/models/check_in.dart';
import 'package:english_village/data/repositories/check_in_repository.dart';
import 'package:english_village/data/sources/check_in_store.dart';
import 'package:english_village/data/sources/settings_store.dart';
import 'package:english_village/features/check_in/check_in_feedback.dart';
import 'package:english_village/features/check_in/check_in_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'ui_test_overrides.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('check_in_page_test');
    Hive.init(directory.path);
    await Hive.openBox<String>(CheckInStore.boxName);
    await Hive.openBox<String>(SettingsStore.boxName);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('a reminder tap keeps an open lesson and opens home when idle', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/account',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Home')),
        GoRoute(path: '/account', builder: (_, _) => const Text('Account')),
        GoRoute(
          path: '/lesson/:lessonId',
          builder: (_, _) => const Text('Lesson'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    unawaited(router.push<void>('/lesson/first'));
    await tester.pumpAndSettle();
    handleCheckInReminderTap(router);
    await tester.pumpAndSettle();
    expect(find.text('Lesson'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    handleCheckInReminderTap(router);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('check-in details update after a locally merged date', (
    tester,
  ) async {
    const store = CheckInStore(userKey: 'guest');
    final repository = CheckInRepository(store: store);
    final now = DateTime.utc(2026, 11, 21);
    await tester.runAsync(() => store.mergeDays(['2026-11-19', '2026-11-20']));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uiStringsOverride,
          checkInClockProvider.overrideWithValue(() => now),
          checkInRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: CheckInPage()),
      ),
    );
    expect(find.text('今日待打卡'), findsOneWidget);
    expect(find.text('连续 2 天'), findsOneWidget);

    await tester.runAsync(() => repository.recordCompletion(now));
    await tester.pumpAndSettle();
    expect(find.text('今日已打卡'), findsOneWidget);
    expect(find.text('连续 3 天'), findsOneWidget);
    expect(find.text('已获得'), findsOneWidget);
    expect(find.text('梭梭树 +1'), findsOneWidget);
  });

  testWidgets('a save retried after midnight shows the original date', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uiStringsOverride,
          checkInClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 11, 21, 16),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CheckInFeedback(
              update: CheckInUpdate(
                newDay: true,
                earned: const [],
                day: DateTime.utc(2026, 11, 21),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('已记录 11 月 21 日打卡'), findsOneWidget);
    expect(find.text('今日已打卡'), findsNothing);
  });
}
