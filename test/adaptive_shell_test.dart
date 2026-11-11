import 'package:english_village/app/adaptive/adaptive_breakpoints.dart';
import 'package:english_village/app/adaptive/adaptive_content_column.dart';
import 'package:english_village/app/adaptive/adaptive_nav_destination.dart';
import 'package:english_village/app/adaptive/app_adaptive_shell.dart';
import 'package:english_village/app/app_strings.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/app/selected_track_controller.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/data/models/skill_practice.dart';
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
}
