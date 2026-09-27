import 'package:english_village/app/theme.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/repositories/reward_repository.dart';
import 'package:english_village/features/lesson/widgets/award_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('passed award can be collected on a compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var collected = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AwardCelebration(
            award: const RewardAward(
              Unit(id: 'u1', title: '问候与自我介绍', description: '', lessons: []),
              2,
              true,
            ),
            onCollect: () => collected = true,
          ),
        ),
      ),
    );
    expect(find.text('闯关成功！'), findsOneWidget);
    expect(find.text('累计 2 枚'), findsOneWidget);
    await tester.tap(find.text('收下徽章'));
    expect(collected, isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('perfect pass shows 完美通关 and cheering characters', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AwardCelebration(
            award: const RewardAward(
              Unit(id: 'u1', title: '问候与自我介绍', description: '', lessons: []),
              5,
              true,
            ),
            isPerfect: true,
            onCollect: () {},
          ),
        ),
      ),
    );
    expect(find.text('完美通关！'), findsOneWidget);
    expect(find.text('米娅'), findsOneWidget);
    expect(find.text('里奥'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('treeCount shows stage line and stage-up highlight', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AwardCelebration(
            award: const RewardAward(
              Unit(id: 'u1', title: '问候与自我介绍', description: '', lessons: []),
              1,
              true,
            ),
            treeCount: 3,
            onCollect: () {},
          ),
        ),
      ),
    );
    // 非升阶：显示常规树计数与阶段名
    expect(find.text('梭梭树 +1 · 累计 3 棵 · 幼苗'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AwardCelebration(
            award: const RewardAward(
              Unit(id: 'u1', title: '问候与自我介绍', description: '', lessons: []),
              1,
              true,
            ),
            treeCount: 5,
            onCollect: () {},
          ),
        ),
      ),
    );
    // 升阶（5 棵 = 小树阈值）：显示高亮升阶文案
    expect(find.text('梭梭树成长为「小树」啦！'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('characters take turns showing fun speech bubbles', (
    tester,
  ) async {
    const miaLines = {
      '太厉害了吧！',
      '这波操作满分！',
      '口语越来越溜啦！',
      '星星都为你闪烁！',
      '保持这个节奏！',
      '你的进步我看在眼里！',
      '今天也是最棒的练习！',
      '厉害厉害！',
    };
    const leoLines = {
      '完美通关，我服！',
      '不愧是你！',
      '英语高手认证！',
      '鼓掌鼓掌！',
      '离学霸又近一步！',
      '徽章拿到手软！',
      '一起冲下一关吧！',
      '膜拜大佬！',
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AwardCelebration(
            award: const RewardAward(
              Unit(id: 'u1', title: '问候与自我介绍', description: '', lessons: []),
              3,
              true,
            ),
            isPerfect: true,
            onCollect: () {},
          ),
        ),
      ),
    );
    // 入场完成后（2.6s），3s 时循环进度 0.75 → 里奥说话
    await tester.pump(const Duration(milliseconds: 3000));
    expect(
      find.byElementPredicate(
        (el) => el.widget is Text && leoLines.contains((el.widget as Text).data),
      ),
      findsOneWidget,
    );
    // 5s 时循环进度 0.25 → 切换为米娅
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.byElementPredicate(
        (el) => el.widget is Text && miaLines.contains((el.widget as Text).data),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
