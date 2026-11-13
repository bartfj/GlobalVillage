# iPad Adaptive Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 宽屏（≥900）显示左侧导航轨 + 右侧约 780 加宽居中内容柱；窄屏保持现有手机布局；课程/专项题面/结果页隐藏导航轨。

**Architecture:** 新增 `lib/app/adaptive/`（断点常量、`AdaptiveContentColumn`、`AppAdaptiveShell`）。用 `go_router` `ShellRoute` 包壳内页；认证与专注路由留在壳外并自行包内容柱。宽屏下收敛 `MainMenuDrawer` 中与导航轨重复的跳转。

**Tech Stack:** Flutter、Riverpod、go_router、现有 `flutter_test`

## Global Constraints

- 规格：`docs/superpowers/specs/2026-11-11-ipad-adaptive-shell-design.md`
- `kAdaptiveRailMinWidth = 900`，`kAdaptiveContentMaxWidth = 780`
- 不改课程数据、同步、账号、判题逻辑
- 不引入新状态管理库；语言/专项仍读现有 providers
- 窄屏（&lt;900）观感与行为必须与改前一致
- 专项入口：`SkillPracticeKind.forLanguage(当前语言).first`；梵文听读仅梵文轨道显示
- 每个 Task 结束单独 commit；测试用 `flutter test <path>`

## File Structure

| Path | Responsibility |
|------|----------------|
| `lib/app/adaptive/adaptive_breakpoints.dart` | 断点与内容柱最大宽度常量 |
| `lib/app/adaptive/adaptive_content_column.dart` | 宽屏限宽居中；窄屏透传 child |
| `lib/app/adaptive/adaptive_nav_destination.dart` | 导航轨目的地模型与选中/显隐逻辑 |
| `lib/app/adaptive/app_adaptive_shell.dart` | 宽屏壳：导航轨 + 内容柱包 `navigationShell` |
| `lib/app/router.dart` | `ShellRoute` 分组；壳外路由保留 |
| `lib/app/app_strings.dart` | 导航轨短文案（中英） |
| `lib/features/learning_path/learning_path_page.dart` | 宽屏去掉徽章 AppBar 入口；蛇形偏移基于内容约束 |
| `lib/features/learning_path/widgets/main_menu_drawer.dart` | 宽屏隐藏重复页面跳转 |
| `lib/features/lesson/lesson_page.dart` | Scaffold body 外包 `AdaptiveContentColumn` |
| `lib/features/lesson/result_page.dart` | 同上 |
| `lib/features/skill_practice/skill_practice_page.dart` | 同上 |
| `lib/features/auth/welcome_page.dart` | body 外包内容柱 |
| `lib/features/auth/login_page.dart` | 同上 |
| `lib/features/auth/register_page.dart` | 同上 |
| `lib/features/sanskrit_audio/sanskrit_audio_page.dart` | 网格按内容柱宽度算列（壳已限宽时通常自然正确；若 LayoutBuilder 在柱内则无需改） |
| `test/adaptive_shell_test.dart` | 断点、内容柱、导航轨显隐、专注路由无轨 |

---

### Task 1: 断点常量与内容柱

**Files:**
- Create: `lib/app/adaptive/adaptive_breakpoints.dart`
- Create: `lib/app/adaptive/adaptive_content_column.dart`
- Create: `test/adaptive_shell_test.dart`

**Interfaces:**
- Produces:
  - `const double kAdaptiveRailMinWidth = 900`
  - `const double kAdaptiveContentMaxWidth = 780`
  - `bool showAdaptiveRail(double width) => width >= kAdaptiveRailMinWidth`
  - `class AdaptiveContentColumn extends StatelessWidget { const AdaptiveContentColumn({super.key, required this.child}); final Widget child; }`
- Consumes: 无

- [ ] **Step 1: Write the failing test**

在 `test/adaptive_shell_test.dart` 写入：

```dart
import 'package:english_village/app/adaptive/adaptive_breakpoints.dart';
import 'package:english_village/app/adaptive/adaptive_content_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('showAdaptiveRail uses 900 breakpoint', () {
    expect(showAdaptiveRail(899), isFalse);
    expect(showAdaptiveRail(900), isTrue);
    expect(showAdaptiveRail(1024), isTrue);
  });

  testWidgets('AdaptiveContentColumn limits width on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveContentColumn(
            child: SizedBox(width: double.infinity, height: 40, key: Key('inner')),
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.byKey(const Key('inner')));
    expect(box.size.width, lessThanOrEqualTo(kAdaptiveContentMaxWidth));
  });

  testWidgets('AdaptiveContentColumn does not clamp on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveContentColumn(
            child: SizedBox(width: double.infinity, height: 40, key: Key('inner')),
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.byKey(const Key('inner')));
    expect(box.size.width, closeTo(390, 0.5));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/adaptive_shell_test.dart`  
Expected: FAIL（库文件不存在 / 未定义）

- [ ] **Step 3: Write minimal implementation**

`lib/app/adaptive/adaptive_breakpoints.dart`:

```dart
const double kAdaptiveRailMinWidth = 900;
const double kAdaptiveContentMaxWidth = 780;

bool showAdaptiveRail(double width) => width >= kAdaptiveRailMinWidth;
```

`lib/app/adaptive/adaptive_content_column.dart`:

```dart
import 'package:flutter/widgets.dart';

import 'adaptive_breakpoints.dart';

/// 宽屏限宽居中；窄屏透传 child。
class AdaptiveContentColumn extends StatelessWidget {
  const AdaptiveContentColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kAdaptiveRailMinWidth) {
          return child;
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kAdaptiveContentMaxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/adaptive_shell_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/app/adaptive/adaptive_breakpoints.dart \
  lib/app/adaptive/adaptive_content_column.dart \
  test/adaptive_shell_test.dart
git commit -m "$(cat <<'EOF'
Add adaptive content column and width breakpoints.

EOF
)"
```

---

### Task 2: 导航目的地模型与壳 UI

**Files:**
- Create: `lib/app/adaptive/adaptive_nav_destination.dart`
- Create: `lib/app/adaptive/app_adaptive_shell.dart`
- Modify: `lib/app/app_strings.dart`（增加轨短文案）
- Modify: `test/adaptive_shell_test.dart`

**Interfaces:**
- Produces:
  - `class AdaptiveNavDestination { final String id; final String location; final IconData icon; final String Function(S s) label; final bool Function(WidgetRef ref) visible; bool matches(String matchedLocation); }`
  - `List<AdaptiveNavDestination> buildAdaptiveNavDestinations()`
  - `class AppAdaptiveShell extends ConsumerWidget { const AppAdaptiveShell({super.key, required this.child}); final Widget child; }` — 宽屏 `Row(rail, Expanded(AdaptiveContentColumn(child)))`；窄屏直接 `child`
- Consumes: `kAdaptiveRailMinWidth`、`AdaptiveContentColumn`、`stringsProvider`、`selectedTrackProvider`、`SkillPracticeKind.forLanguage`

- [ ] **Step 1: Add string getters**

在 `lib/app/app_strings.dart` 的 `S` 中增加（靠近现有 stats/section 文案）：

```dart
  String get navPath => isEn ? 'Path' : '路径';
  String get navPractice => isEn ? 'Practice' : '练习';
  String get navCompleted => isEn ? 'Done' : '已完成';
  String get navAccount => isEn ? 'Account' : '账号';
  String get navTree => isEn ? 'Tree' : '梭梭树';
```

复用已有：`sanskritAudioTitle`、`reviewRecords`、`statsBadges`（轨上徽章可用更短，若过长可再加 `navBadges => isEn ? 'Badges' : '徽章'`）。

- [ ] **Step 2: Write failing tests for destination matching / visibility**

追加到 `test/adaptive_shell_test.dart`：

```dart
import 'package:english_village/app/adaptive/adaptive_nav_destination.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/data/models/skill_practice.dart';

  test('practice destination matches chapter routes by prefix', () {
    final dest = AdaptiveNavDestination(
      id: 'practice',
      location: '/practice/pronunciation',
      icon: Icons.school,
      label: (s) => 'Practice',
      visible: (_) => true,
    );
    expect(dest.matches('/practice/pronunciation'), isTrue);
    expect(dest.matches('/practice/pronunciation/ch1'), isTrue);
    expect(dest.matches('/'), isFalse);
  });

  test('forLanguage first skill is pronunciation for english', () {
    expect(
      SkillPracticeKind.forLanguage(LearningLanguage.english).first,
      SkillPracticeKind.pronunciation,
    );
  });
```

（`AdaptiveNavDestination.matches`：对 `/` 精确匹配；其它用 `matchedLocation == location || matchedLocation.startsWith('$location/')`。练习项 `location` 为 `/practice/<first>`，匹配所有 `/practice/` 前缀时可特判：`id == 'practice' && matchedLocation.startsWith('/practice/')`。）

- [ ] **Step 3: Run tests — expect fail**

Run: `flutter test test/adaptive_shell_test.dart`  
Expected: FAIL on missing `adaptive_nav_destination.dart`

- [ ] **Step 4: Implement destinations + shell**

`adaptive_nav_destination.dart` 要点：

```dart
class AdaptiveNavDestination {
  const AdaptiveNavDestination({
    required this.id,
    required this.location,
    required this.icon,
    required this.label,
    required this.visible,
  });

  final String id;
  final String location;
  final IconData icon;
  final String Function(S s) label;
  final bool Function(WidgetRef ref) visible;

  bool matches(String matchedLocation) {
    if (id == 'path') return matchedLocation == '/';
    if (id == 'practice') {
      return matchedLocation.startsWith('/practice/');
    }
    return matchedLocation == location ||
        matchedLocation.startsWith('$location/');
  }
}

List<AdaptiveNavDestination> buildAdaptiveNavDestinations() {
  return [
    AdaptiveNavDestination(
      id: 'path',
      location: '/',
      icon: Icons.route_rounded,
      label: (s) => s.navPath,
      visible: (_) => true,
    ),
    AdaptiveNavDestination(
      id: 'practice',
      location: '/practice/pronunciation', // 壳内用 ref 覆盖为 forLanguage.first
      icon: Icons.fitness_center_rounded,
      label: (s) => s.navPractice,
      visible: (ref) =>
          SkillPracticeKind.forLanguage(
            ref.read(selectedTrackProvider).language,
          ).isNotEmpty,
    ),
    // sanskrit-audio: visible 仅 LearningLanguage.sanskrit
    // completed -> /completed, review -> /review,
    // badges -> /badges, tree -> /tree, account -> /account
  ];
}
```

练习项实际 `go` 目标在壳里计算：

```dart
String practiceLocation(WidgetRef ref) {
  final skills = SkillPracticeKind.forLanguage(
    ref.read(selectedTrackProvider).language,
  );
  return '/practice/${skills.first.name}';
}
```

`AppAdaptiveShell`：

```dart
class AppAdaptiveShell extends ConsumerWidget {
  const AppAdaptiveShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = showAdaptiveRail(constraints.maxWidth);
        final body = AdaptiveContentColumn(child: child);
        if (!wide) return body;
        final matched = GoRouterState.of(context).matchedLocation;
        final s = ref.watch(stringsProvider);
        final destinations = buildAdaptiveNavDestinations()
            .where((d) => d.visible(ref))
            .toList();
        final selected = destinations.indexWhere((d) => d.matches(matched));
        return Row(
          children: [
            NavigationRail(
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (i) {
                final d = destinations[i];
                final loc = d.id == 'practice' ? practiceLocation(ref) : d.location;
                if (loc != matched) context.go(loc);
              },
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label(s)),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
```

若 8 个 `NavigationRailDestination` 在矮屏溢出：把轨包在 `SingleChildScrollView` + 固定宽约 88 的自定义列（`Icon`+`Text`），行为与 `onDestinationSelected` 相同。优先保证不溢出。

- [ ] **Step 5: Widget test shell shows rail only when wide**

```dart
  testWidgets('AppAdaptiveShell shows NavigationRail only when wide', (
    tester,
  ) async {
    // 用最小 GoRouter：ShellRoute builder 返回 AppAdaptiveShell(child: child)
    // initialLocation '/'，routes 一个假首页 Text('home')
    // 宽度 390：find.byType(NavigationRail) findsNothing
    // 宽度 1024：findsOneWidget
  });
```

实现时用本地 `ProviderScope` + 覆盖 `stringsProvider` / `selectedTrackProvider` 若构建轨需要；若轨在 build 里 `watch` strings，需与 `main.dart` 相同的 override，或让测试 pump 真实 `ProviderScope` 并 `Hive` 初始化——**优先**：壳测试只 pump `MaterialApp` + 手写 `GoRouter`，对 `selectedTrackProvider` 用 `ProviderScope(overrides: [...])`。参考 `test/online_auth_test.dart` 的 override 写法。若成本过高，本步可测「用 `showAdaptiveRail` + 条件渲染的假壳」，完整轨留到 Task 3 路由测试。

- [ ] **Step 6: Run tests — expect pass**

Run: `flutter test test/adaptive_shell_test.dart`  
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/app/adaptive/adaptive_nav_destination.dart \
  lib/app/adaptive/app_adaptive_shell.dart \
  lib/app/app_strings.dart \
  test/adaptive_shell_test.dart
git commit -m "$(cat <<'EOF'
Add adaptive shell navigation rail for wide layouts.

EOF
)"
```

---

### Task 3: 接入 ShellRoute

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `test/adaptive_shell_test.dart`（或新建 `test/adaptive_router_test.dart`）

**Interfaces:**
- Consumes: `AppAdaptiveShell`
- Produces: 壳内路由经 `ShellRoute`；壳外：`welcome/login/register/lesson/result/practice/:skill/:chapterId`

- [ ] **Step 1: Restructure routes**

将 `routes` 改为大致结构（保持现有 `redirect` / observers / refreshListenable）：

```dart
routes: [
  ShellRoute(
    builder: (context, state, child) => AppAdaptiveShell(child: child),
    routes: [
      GoRoute(path: '/', builder: ..., ),
      GoRoute(path: '/review', ...),
      GoRoute(path: '/sanskrit-audio', ...),
      GoRoute(
        path: '/practice/:skill',
        builder: (context, state) => SkillPracticeChaptersPage(...),
        // 注意：chapter 子路由不要放在壳内
      ),
      GoRoute(path: '/badges', ...),
      GoRoute(path: '/rewards', redirect: ...),
      GoRoute(path: '/tree', ...),
      GoRoute(path: '/completed', ...),
      GoRoute(path: '/account', ...),
    ],
  ),
  GoRoute(path: '/welcome', ...),
  GoRoute(path: '/login', ...),
  GoRoute(path: '/register', ...),
  GoRoute(path: '/lesson/:lessonId', ...),
  GoRoute(path: '/lesson/:lessonId/result', ...),
  GoRoute(
    path: '/practice/:skill/:chapterId',
    builder: (context, state) => SkillPracticePage(...),
  ),
],
```

**重要：** 原先 `practice/:skill` 下嵌套 `:chapterId`。改为并列的顶层 `/practice/:skill/:chapterId`（更具体路径），避免 chapter 页进壳。确认 `context.push('/practice/${skill.name}/$chapterId')` 仍解析到专注页。

- [ ] **Step 2: Write router chrome test**

用可注入假页的测试路由，或 `goRouterProvider` + overrides：

```dart
testWidgets('lesson route has no NavigationRail on wide screen', (tester) async {
  tester.view.physicalSize = const Size(1200, 900);
  // pump app with router at /lesson/x （可用假 LessonPage 或跳过业务依赖的最小 router）
  // expect(find.byType(NavigationRail), findsNothing);
});

testWidgets('home route has NavigationRail on wide screen', (tester) async {
  // expect findsOneWidget
});
```

若完整 `LearningPathPage` 依赖过重，本 Task 的测试可用临时 `GoRoute` 假首页验证 `ShellRoute` 接线；生产 `router.dart` 仍接真页面。

- [ ] **Step 3: Manual sanity**

Run: `flutter test test/adaptive_shell_test.dart`  
Run: 相关现有测试若有路由依赖则跑 `flutter test test/skill_practice_test.dart`（若 push 路径变了）  
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/app/router.dart test/adaptive_shell_test.dart
git commit -m "$(cat <<'EOF'
Wire adaptive shell into go_router ShellRoute.

EOF
)"
```

---

### Task 4: 学习路径与抽屉收敛

**Files:**
- Modify: `lib/features/learning_path/learning_path_page.dart`
- Modify: `lib/features/learning_path/widgets/main_menu_drawer.dart`

**Interfaces:**
- Consumes: `showAdaptiveRail`、`kAdaptiveContentMaxWidth`（偏移用 LayoutBuilder 的 `constraints.maxWidth`，壳已限宽时自然正确）
- Produces: 宽屏无徽章 AppBar 按钮；抽屉宽屏隐藏重复跳转

- [ ] **Step 1: AppBar badges**

在 `learning_path_page.dart` 的 `actions` 中，宽屏不加入徽章 `IconButton`：

```dart
actions: [
  IconButton( /* unit directory — always */ ),
  if (!showAdaptiveRail(MediaQuery.sizeOf(context).width))
    IconButton( /* badges */ ),
  Center( /* completed count */ ),
],
```

- [ ] **Step 2: Drawer — hide duplicate jumps when wide**

给 `MainMenuDrawer` 增加可选参数，或在 build 内读宽度：

```dart
final wide = showAdaptiveRail(MediaQuery.sizeOf(context).width);
```

宽屏时：

- `_StatsCard` 的 `onTap` 传 `null`（仅展示数字）
- `_AccountCard` 的 `onOpen` 在宽屏且非游客时仍可进账号 **或** 改为 `null`（轨已有账号）——按规格隐藏重复：**`onOpen: null`**
- `_SectionCard` 专项练习整块：宽屏 **保留**（多个 skill 入口，轨只有「练习」一项）——规格写的是隐藏与轨重复的跳转；专项多入口仍有价值，**宽屏保留专项列表**；隐藏：梵文听读行若轨已有则可藏、`reviewRecords` 行、统计卡三跳转、账号卡打开
- 「更多」里只留界面语言、服务地址、备份、反馈、关于、退出等

明确清单（宽屏隐藏）：

| UI | 宽屏 |
|----|------|
| 统计卡 → completed/tree/badges | `onTap: null` |
| 账号卡 → /account | `onOpen: null` |
| 梵文听读菜单行 | 隐藏（轨有） |
| 复习与学习记录行 | 隐藏（轨有） |
| 各 skill `/practice/...` 行 | **保留**（多专项） |
| 备份/反馈/关于/语言/服务器/退出 | 保留 |

- [ ] **Step 3: Snake offset**

确认 `LayoutBuilder` 已在 body；壳限宽后 `constraints.maxWidth` 即内容柱宽，**无需改公式**。若页面未被内容柱包到（壳已包），验证偏移不再按 1024 整屏拉飞即可。手动或加 golden/widget 非必须。

- [ ] **Step 4: Commit**

```bash
git add lib/features/learning_path/learning_path_page.dart \
  lib/features/learning_path/widgets/main_menu_drawer.dart
git commit -m "$(cat <<'EOF'
Tighten learning path chrome for wide adaptive shell.

EOF
)"
```

---

### Task 5: 壳外页包内容柱

**Files:**
- Modify: `lib/features/lesson/lesson_page.dart`
- Modify: `lib/features/lesson/result_page.dart`
- Modify: `lib/features/skill_practice/skill_practice_page.dart`
- Modify: `lib/features/auth/welcome_page.dart`
- Modify: `lib/features/auth/login_page.dart`
- Modify: `lib/features/auth/register_page.dart`

**Interfaces:**
- Consumes: `AdaptiveContentColumn`

- [ ] **Step 1: Wrap each page**

模式（以 lesson 为例）：在 `Scaffold` 外包或 `body:` 内最外层：

```dart
return PopScope(
  ...
  child: AdaptiveContentColumn(
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // existing header / exercise / footer
          ],
        ),
      ),
    ),
  ),
);
```

认证页：`Scaffold` → `body: AdaptiveContentColumn(child: SafeArea(...现有...))`。

结果页、专项题面同样包一层，避免宽屏题面拉满。

- [ ] **Step 2: Run a smoke test**

Run: `flutter test test/adaptive_shell_test.dart`  
Run: `flutter test test/dialogue_performance_test.dart`（若受 lesson 结构影响）  
Expected: PASS（或仅失败于无关项则修复）

- [ ] **Step 3: Commit**

```bash
git add lib/features/lesson/lesson_page.dart \
  lib/features/lesson/result_page.dart \
  lib/features/skill_practice/skill_practice_page.dart \
  lib/features/auth/welcome_page.dart \
  lib/features/auth/login_page.dart \
  lib/features/auth/register_page.dart
git commit -m "$(cat <<'EOF'
Wrap focus and auth pages in the adaptive content column.

EOF
)"
```

---

### Task 6: 验收测试补强与规格对照

**Files:**
- Modify: `test/adaptive_shell_test.dart`
- Modify: `docs/superpowers/specs/2026-11-11-ipad-adaptive-shell-design.md`（若实现细节有必要回写「已实现」状态一行，可选）

- [ ] **Step 1: Add acceptance-oriented tests**

```dart
test('constants match spec', () {
  expect(kAdaptiveRailMinWidth, 900);
  expect(kAdaptiveContentMaxWidth, 780);
});

test('sanskrit audio nav visible only for sanskrit track', () {
  final dests = buildAdaptiveNavDestinations();
  final audio = dests.firstWhere((d) => d.id == 'sanskrit-audio');
  // 用假 WidgetRef 困难时：把 visible 逻辑抽成
  // bool sanskritAudioVisible(LearningLanguage lang) => lang == LearningLanguage.sanskrit;
  expect(sanskritAudioVisible(LearningLanguage.english), isFalse);
  expect(sanskritAudioVisible(LearningLanguage.sanskrit), isTrue);
});
```

若 `visible` 闭包难测，抽出纯函数到 `adaptive_nav_destination.dart`。

- [ ] **Step 2: Full adaptive test file**

Run: `flutter test test/adaptive_shell_test.dart`  
Expected: PASS

- [ ] **Step 3: Manual checklist**（执行者在模拟器勾选）

- [ ] iPad/宽屏模拟器 ≥900：有导航轨，内容居中不拉满
- [ ] 点练习进章节地图：有轨；再进 chapter 题面：无轨
- [ ] 进 lesson / result：无轨
- [ ] iPhone 390 宽：无轨，抽屉跳转齐全
- [ ] 梵文轨道显示听读；英语轨道不显示

- [ ] **Step 4: Commit**

```bash
git add test/adaptive_shell_test.dart lib/app/adaptive/
git commit -m "$(cat <<'EOF'
Cover adaptive shell acceptance cases with tests.

EOF
)"
```

---

## Spec coverage (self-review)

| Spec 要求 | Task |
|-----------|------|
| 断点 900 / 内容柱 780 | Task 1 |
| 导航轨 + 加宽居中壳 | Task 2 |
| ShellRoute 进壳/不进壳路由表 | Task 3 |
| 做题隐藏轨 | Task 3（路由在壳外） |
| 轨入口与显隐 | Task 2 |
| 路径 AppBar/抽屉收敛 | Task 4 |
| 认证/专注限宽 | Task 5 |
| 测试与验收 | Task 1–2、6 |

无 TBD 占位；练习路由拆分在 Task 3 写清，避免 chapter 误进壳。
