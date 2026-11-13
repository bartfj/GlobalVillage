import 'package:english_village/app/adaptive/adaptive_breakpoints.dart';
import 'package:english_village/app/adaptive/adaptive_content_column.dart';
import 'package:english_village/app/adaptive/adaptive_nav_destination.dart';
import 'package:english_village/app/adaptive/app_adaptive_shell.dart';
import 'package:english_village/app/app_strings.dart';
import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/app/router.dart';
import 'package:english_village/app/selected_track_controller.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/data/models/skill_practice.dart';
import 'package:english_village/features/skill_practice/skill_practice_chapters_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FixedTrack extends StateNotifier<CourseTrack>
    implements SelectedTrackController {
  _FixedTrack(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth(bool signedIn)
    : super(signedIn ? const AuthState(userKey: 'test') : const AuthState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GoRouter _chromeRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppAdaptiveShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => TextButton(
              onPressed: () => context.push('/lesson/x'),
              child: const Text('home'),
            ),
          ),
          GoRoute(
            path: '/practice/:skill',
            builder: (context, state) => TextButton(
              onPressed: () => context.push(
                '/practice/${state.pathParameters['skill']}/ch1',
              ),
              child: Text('practice:${state.pathParameters['skill']}'),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/lesson/:lessonId',
        builder: (context, state) =>
            Text('lesson:${state.pathParameters['lessonId']}'),
      ),
      GoRoute(
        path: '/practice/:skill/:chapterId',
        builder: (context, state) => Text(
          'chapter:${state.pathParameters['skill']}/${state.pathParameters['chapterId']}',
        ),
      ),
    ],
  );
}

Future<void> _pumpChrome(
  WidgetTester tester,
  GoRouter router, {
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        stringsProvider.overrideWithValue(const S(UiLanguage.chinese)),
        selectedTrackProvider.overrideWith(
          (ref) => _FixedTrack(CourseTrack.beginner),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  test('constants match spec', () {
    expect(kAdaptiveRailMinWidth, 900);
    expect(kAdaptiveContentMaxWidth, 780);
  });

  test('sanskrit audio nav visible only for sanskrit track', () {
    expect(sanskritAudioVisible(LearningLanguage.english), isFalse);
    expect(sanskritAudioVisible(LearningLanguage.sanskrit), isTrue);

    final dests = buildAdaptiveNavDestinations();
    final audio = dests.firstWhere((d) => d.id == 'sanskrit-audio');
    expect(audio.id, 'sanskrit-audio');
    expect(audio.location, '/sanskrit-audio');
  });

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
            child: SizedBox(
              width: double.infinity,
              height: 40,
              key: Key('inner'),
            ),
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
            child: SizedBox(
              width: double.infinity,
              height: 40,
              key: Key('inner'),
            ),
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.byKey(const Key('inner')));
    expect(box.size.width, closeTo(390, 0.5));
  });

  testWidgets('shell forces 780 content width beside the rail', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppAdaptiveShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const SizedBox(
                key: Key('page'),
                width: double.infinity,
                height: 48,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> expectClamped(Size size) async {
      await _pumpChrome(tester, router, size: size);
      expect(find.byType(NavigationRail), findsOneWidget);

      final pageRect = tester.getRect(find.byKey(const Key('page')));
      final alignRect = tester.getRect(
        find
            .ancestor(
              of: find.byKey(const Key('page')),
              matching: find.byType(Align),
            )
            .first,
      );
      expect(alignRect.width, greaterThan(kAdaptiveContentMaxWidth));
      expect(pageRect.width, lessThanOrEqualTo(kAdaptiveContentMaxWidth));
      expect(pageRect.width, closeTo(kAdaptiveContentMaxWidth, 0.5));
      final expectedLeft =
          alignRect.left + (alignRect.width - pageRect.width) / 2;
      expect(pageRect.left, closeTo(expectedLeft, 0.5));
    }

    await expectClamped(const Size(1024, 800));
    await expectClamped(const Size(920, 800));
  });

  testWidgets('popOrGoHome pops when a page is still on the stack', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(path: '/a', builder: (context, state) => const Text('page-a')),
        GoRoute(
          path: '/b',
          builder: (context, state) => TextButton(
            onPressed: () => popOrGoHome(context),
            child: const Text('back'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/b');
    await tester.pumpAndSettle();
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('page-a'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/a');
  });

  testWidgets('chapter map back after rail go returns home', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppAdaptiveShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (context, state) => const Text('home')),
            GoRoute(
              path: '/practice/:skill',
              builder: (context, state) => TextButton(
                onPressed: () => popOrGoHome(context),
                child: const Text('map-back'),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpChrome(tester, router, size: const Size(1024, 800));
    await tester.tap(find.text('练习'));
    await tester.pumpAndSettle();
    expect(find.text('map-back'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, isNot('/'));

    await tester.tap(find.text('map-back'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('home'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  test('path destination matches only the root location', () {
    final dest = AdaptiveNavDestination(
      id: 'path',
      location: '/',
      icon: Icons.route_rounded,
      label: (s) => 'Path',
      visible: (_) => true,
    );
    expect(dest.matches('/'), isTrue);
    expect(dest.matches('/lesson/a'), isFalse);
    expect(dest.matches('/completed'), isFalse);
  });

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

  testWidgets('AppAdaptiveShell shows NavigationRail only when wide', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppAdaptiveShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (context, state) => const Text('home')),
            GoRoute(
              path: '/practice/:skill',
              builder: (context, state) =>
                  Text('practice:${state.pathParameters['skill']}'),
            ),
            GoRoute(
              path: '/sanskrit-audio',
              builder: (context, state) => const Text('sanskrit-audio'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final track = _FixedTrack(CourseTrack.beginner);

    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stringsProvider.overrideWithValue(const S(UiLanguage.chinese)),
            selectedTrackProvider.overrideWith((ref) => track),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
    }

    await pumpAt(const Size(390, 800));
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('home'), findsOneWidget);

    await pumpAt(const Size(1024, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('路径'), findsOneWidget);
    expect(find.text('练习'), findsOneWidget);
    expect(find.text('梵文发音'), findsNothing);

    await tester.tap(find.text('练习'));
    await tester.pumpAndSettle();
    expect(find.text('practice:pronunciation'), findsOneWidget);

    await pumpAt(const Size(1024, 320));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);

    track.state = CourseTrack.sanskrit;
    await tester.pump();
    expect(find.text('梵文发音'), findsOneWidget);

    await tester.tap(find.text('练习'));
    await tester.pumpAndSettle();
    expect(find.text('practice:sanskritLetters'), findsOneWidget);
  });

  testWidgets('home route has NavigationRail on wide screen', (tester) async {
    final router = _chromeRouter();
    addTearDown(router.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpChrome(tester, router);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('lesson route has no NavigationRail on wide screen', (
    tester,
  ) async {
    final router = _chromeRouter(initialLocation: '/lesson/x');
    addTearDown(router.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpChrome(tester, router);

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('lesson:x'), findsOneWidget);
  });

  testWidgets('pushed lesson and chapter routes leave the shell', (
    tester,
  ) async {
    final router = _chromeRouter();
    addTearDown(router.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpChrome(tester, router);
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('lesson:x'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);

    router.go('/practice/pronunciation');
    await tester.pumpAndSettle();
    expect(find.text('practice:pronunciation'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);

    await tester.tap(find.text('practice:pronunciation'));
    await tester.pumpAndSettle();
    expect(find.text('chapter:pronunciation/ch1'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('practice:pronunciation'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('production router keeps focus routes outside the shell', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _Auth(true)),
        selectedTrackProvider.overrideWith(
          (ref) => _FixedTrack(CourseTrack.beginner),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(goRouterProvider);

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );

    void expectShell(String location, bool inShell, String fullPath) {
      final match = router.configuration.findMatch(Uri.parse(location));
      expect(match.error, isNull, reason: location);
      expect(match.fullPath, fullPath, reason: location);
      expect(
        match.matches.any((m) => m is ShellRouteMatch),
        inShell,
        reason: location,
      );
    }

    expectShell('/', true, '/');
    expectShell('/review', true, '/review');
    expectShell('/sanskrit-audio', true, '/sanskrit-audio');
    expectShell('/practice/pronunciation', true, '/practice/:skill');
    expectShell('/badges', true, '/badges');
    expectShell('/rewards', true, '/rewards');
    expectShell('/tree', true, '/tree');
    expectShell('/completed', true, '/completed');
    expectShell('/account', true, '/account');
    expectShell('/welcome', false, '/welcome');
    expectShell('/login', false, '/login');
    expectShell('/register', false, '/register');
    expectShell('/lesson/abc', false, '/lesson/:lessonId');
    expectShell('/lesson/abc/result', false, '/lesson/:lessonId/result');
    expectShell(
      '/practice/pronunciation/ch1',
      false,
      '/practice/:skill/:chapterId',
    );

    final chapter = router.configuration.findMatch(
      Uri.parse('/practice/pronunciation/ch1'),
    );
    expect(chapter.pathParameters['skill'], 'pronunciation');
    expect(chapter.pathParameters['chapterId'], 'ch1');

    final shell = router.configuration.routes.whereType<ShellRoute>().single;
    final practice = shell.routes.whereType<GoRoute>().singleWhere(
      (route) => route.path == '/practice/:skill',
    );
    expect(practice.routes, isEmpty);

    Future<String> resolve(String location) async {
      router.go(location);
      final match = await router.routeInformationParser
          .parseRouteInformationWithDependencies(
            router.routeInformationProvider.value,
            context,
          );
      return match.uri.path;
    }

    expect(
      await resolve('/practice/pronunciation/ch1'),
      '/practice/pronunciation/ch1',
    );
    expect(await resolve('/practice/sanskritLetters/ch1'), '/');
    expect(await resolve('/lesson/abc'), '/lesson/abc');
    expect(await resolve('/rewards'), '/badges');

    final signedOut = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _Auth(false)),
        selectedTrackProvider.overrideWith(
          (ref) => _FixedTrack(CourseTrack.beginner),
        ),
      ],
    );
    addTearDown(signedOut.dispose);
    final gated = signedOut.read(goRouterProvider);
    gated.go('/');
    final welcome = await gated.routeInformationParser
        .parseRouteInformationWithDependencies(
          gated.routeInformationProvider.value,
          context,
        );
    expect(welcome.uri.path, '/welcome');
    expect(welcome.matches.any((m) => m is ShellRouteMatch), isFalse);
  });
}
