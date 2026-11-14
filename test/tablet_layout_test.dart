import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:english_village/app/adaptive/adaptive_content_column.dart';
import 'package:english_village/app/adaptive/app_adaptive_shell.dart';
import 'package:english_village/app/app_strings.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/app/theme.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/features/learning_path/learning_path_page.dart';
import 'package:english_village/features/learning_path/widgets/main_menu_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'adaptive_test_overrides.dart';

GoRouter _router({bool realHome = false}) => GoRouter(
  routes: [
    ShellRoute(
      builder: (_, _, child) => AppAdaptiveShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => realHome
              ? const LearningPathPage()
              : const Scaffold(key: Key('page'), body: Text('home')),
        ),
        GoRoute(
          path: '/completed',
          builder: (_, _) =>
              const Scaffold(key: Key('page'), body: Text('completed-page')),
        ),
        GoRoute(
          path: '/practice/:skill',
          builder: (_, state) => Scaffold(
            key: const Key('page'),
            body: Text('practice:${state.pathParameters['skill']}'),
          ),
        ),
      ],
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  GoRouter router, {
  Size size = const Size(1366, 900),
  UiLanguage language = UiLanguage.chinese,
  double textScale = 1,
  TargetPlatform? platform,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: adaptiveTestOverrides(
        language: language,
        previewCourse: Platform.environment['TABLET_SCREENSHOT_DIR'] == null
            ? null
            : Course.fromJson(
                jsonDecode(
                      File(
                        'assets/courses/course_beginner.json',
                      ).readAsStringSync(),
                    )
                    as Map<String, dynamic>,
              ),
      ),
      child: RepaintBoundary(
        key: const Key('tablet-capture'),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme().copyWith(
            platform: platform,
            textTheme: Platform.environment['TABLET_SCREENSHOT_DIR'] == null
                ? null
                : buildAppTheme().textTheme.apply(fontFamily: 'LayoutPreview'),
          ),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  if (find.byType(LearningPathPage).evaluate().isNotEmpty) {
    // The current lesson pulse repeats; allow finite route/layout animations.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['TABLET_SCREENSHOT_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('tablet-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    if (Platform.environment['TABLET_SCREENSHOT_DIR'] == null) return;
    for (final (family, path) in [
      ('LayoutPreview', 'C:/Windows/Fonts/msyh.ttc'),
      (
        'MaterialIcons',
        'D:/fv_sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    ]) {
      final loader = FontLoader(family);
      loader.addFont(
        File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });

  for (final language in UiLanguage.values) {
    testWidgets('real tablet home supports large ${language.name} text', (
      tester,
    ) async {
      await _pump(
        tester,
        _router(realHome: true),
        language: language,
        textScale: 1.8,
      );
      final home = find.descendant(
        of: find.byType(LearningPathPage),
        matching: find.byType(Scaffold),
      );
      expect(tester.getRect(home).right, closeTo(1366, .5));
      expect(find.byType(MainMenuDrawer), findsOneWidget);
      expect(tester.widget<Scaffold>(home).drawer, isNull);
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'tablet-${language.name}-large-text');
    });
  }

  testWidgets('home switches between fixed menu and phone drawer on rotation', (
    tester,
  ) async {
    await _pump(tester, _router(realHome: true));
    await _capture(tester, 'tablet-chinese');
    tester.view.physicalSize = const Size(390, 844);
    await _settle(tester);
    expect(find.byKey(const ValueKey('adaptive-main-menu')), findsNothing);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await _settle(tester);
    expect(find.text('test'), findsOneWidget);
    await _capture(tester, 'phone-chinese-menu');
    tester.view.physicalSize = const Size(1024, 768);
    await _settle(tester);
    expect(find.byKey(const ValueKey('adaptive-main-menu')), findsOneWidget);
    expect(find.byType(MainMenuDrawer), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'tablet-1024');
  });

  testWidgets(
    'tablet uses the complete phone menu with account and course cards',
    (tester) async {
      await _pump(tester, _router());
      expect(find.byType(MainMenuDrawer), findsOneWidget);
      expect(find.text('test'), findsOneWidget);
      expect(
        find.text(const S(UiLanguage.chinese).statsCompleted),
        findsOneWidget,
      );
      expect(
        find.text(const S(UiLanguage.chinese).sectionCourses),
        findsOneWidget,
      );
      expect(
        find.text(const S(UiLanguage.chinese).motherPatternTitle),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('fixed menu dialogs can close without closing the current page', (
    tester,
  ) async {
    final router = _router();
    await _pump(tester, router);
    for (final (label, title, close) in [
      (const S(UiLanguage.chinese).about, '地球村', '知道了'),
      (const S(UiLanguage.chinese).logoutSwitch, '退出当前账号？', '取消'),
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text(close));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('page')), findsOneWidget);
      expect(find.byType(MainMenuDrawer), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('fixed language selector returns from practice to the new path', (
    tester,
  ) async {
    final router = _router();
    await _pump(tester, router);
    router.go('/practice/pronunciation');
    await tester.pumpAndSettle();
    const s = S(UiLanguage.chinese);
    await tester.tap(find.text(s.switchCourse));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.languageLabel(LearningLanguage.sanskrit)));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainMenuDrawer)),
    );
    expect(
      container.read(selectedTrackProvider).language,
      LearningLanguage.sanskrit,
    );
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.byType(MainMenuDrawer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet page fills the remaining width through the right edge', (
    tester,
  ) async {
    await _pump(tester, _router());
    final rect = tester.getRect(find.byKey(const Key('page')));
    expect(rect.width, greaterThan(780));
    expect(rect.left, inInclusiveRange(280, 400));
    expect(rect.right, closeTo(1366, .5));
  });

  testWidgets(
    'persistent completed action changes page without popping the shell',
    (tester) async {
      final router = _router();
      await _pump(tester, router);
      await tester.tap(find.text(const S(UiLanguage.chinese).statsCompleted));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/completed');
      expect(find.text('completed-page'), findsOneWidget);
      expect(find.byType(MainMenuDrawer), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide focused pages paint their outside margins instead of transparency',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaintBoundary(
            key: Key('surface'),
            child: AdaptiveContentColumn(
              child: Scaffold(body: Text('focused page')),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('surface')),
      );
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return bytes!;
      });
      final pixel = (400 * 1366 + 16) * 4;
      expect(bytes!.getUint8(pixel + 3), 255);
      expect(bytes.getUint8(pixel), greaterThan(230));
    },
  );
}
