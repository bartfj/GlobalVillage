import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/repositories/reward_repository.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/features/learning_path/learning_path_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_overrides.dart';

class TestAuth extends StateNotifier<AuthState> implements AuthController {
  TestAuth() : super(const AuthState(userKey: 'test'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestProgress implements ProgressStore {
  int completed = 30;
  @override
  LessonProgress? get(String id) => int.parse(id.substring(1)) <= completed
      ? LessonProgress(
          lessonId: id,
          completed: true,
          score: 100,
          correctCount: 9,
          totalCount: 9,
        )
      : null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestRewards implements RewardRepository {
  @override
  int get treeCount => 0;
  @override
  int unlockedBadgeCount(Iterable<Course> courses) => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final course = Course(
    id: 'test',
    title: '测试课程',
    units: [
      for (var u = 0; u < 10; u++)
        Unit(
          id: 'u$u',
          title: '单元 $u',
          description: '较长的单元介绍用于验证实际布局定位而非固定高度估算',
          lessons: [
            for (var i = 1; i <= 4; i++)
              Lesson(
                id: 'l${u * 4 + i}',
                title: '课程 ${u * 4 + i}',
                exercises: const [],
              ),
          ],
        ),
    ],
  );

  testWidgets(
    'locates lesson 31, preserves browsing and advances with progress',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = TestProgress();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => TestAuth()),
          courseProvider.overrideWithValue(course),
          progressRepositoryProvider.overrideWithValue(
            ProgressRepository(store: store, course: course),
          ),
          rewardRepositoryProvider.overrideWithValue(TestRewards()),
          allCoursesProvider.overrideWith((ref) async => [course]),
          uiStringsOverride,
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LearningPathPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('第31节 · 课程 31'), findsOneWidget);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.pixels, greaterThan(1000));
      expect(
        tester.getRect(find.byKey(const ValueKey('l31'))).top,
        inInclusiveRange(56, 550),
      );
      scrollable.position.jumpTo(0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('回到当前课'), findsOneWidget);
      container.read(progressRevisionProvider.notifier).state++;
      await tester.pump(const Duration(milliseconds: 500));
      expect(scrollable.position.pixels, 0);
      await tester.tap(find.byTooltip('回到当前课'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(scrollable.position.pixels, greaterThan(1000));
      await tester.tap(find.byTooltip('单元目录'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('单元 0').last);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(scrollable.position.pixels, lessThan(100));
      store.completed = 31;
      container.read(progressRevisionProvider.notifier).state++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('第32节 · 课程 32'), findsOneWidget);
      expect(scrollable.position.pixels, greaterThan(1000));
      store.completed = 40;
      container.read(progressRevisionProvider.notifier).state++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('全部完成'), findsOneWidget);
      expect(find.text('复习'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('l40'))).top,
        inInclusiveRange(56, 620),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
