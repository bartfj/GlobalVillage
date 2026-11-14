import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:english_village/app/app_strings.dart';
import 'package:english_village/features/post_lesson_comedy/comedy_catalog.dart';
import 'package:english_village/features/post_lesson_comedy/post_lesson_comedy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'exact lessons take precedence over the course recommendation',
    () async {
      final catalog = await ComedyCatalog.load();
      const cases = {
        'zero/z_u2l1': 'Z01',
        'zero/z_u3l1': 'Z02',
        'zero/z_u4l1': 'Z03',
        'beginner/u4l4': 'B01',
        'beginner/u9l1': 'B02',
        'beginner/u23l1': 'B03',
        'motherPattern/mp_u1l3': 'M01',
        'motherPattern/mp_u2l2': 'M02',
        'motherPattern/mp_u3l1': 'M03',
        'intermediate/i_u3l4': 'I01',
        'intermediate/i_u5l1': 'I02',
        'intermediate/i_u7l2': 'I03',
      };
      for (final entry in cases.entries) {
        final ids = entry.key.split('/');
        expect(catalog.recommend(ids[0], ids[1])?.id, entry.value);
      }
    },
  );

  test(
    'all four English tracks recommend content for unadapted lessons',
    () async {
      final catalog = await ComedyCatalog.load();
      for (final course in [
        'zero',
        'beginner',
        'motherPattern',
        'intermediate',
      ]) {
        expect(catalog.recommend(course, 'unadapted')?.courseId, course);
      }
      for (final course in [
        'chinese',
        'chineseZero',
        'sanskrit',
        'sanskritZero',
        'unknown',
      ]) {
        expect(catalog.recommend(course, 'mp_u1l3'), isNull);
      }
    },
  );

  test(
    'every bundled English lesson gets a recommendation in its track',
    () async {
      final catalog = await ComedyCatalog.load();
      var checked = 0;
      for (final name in [
        'zero',
        'beginner',
        'intermediate',
        'mother_pattern',
      ]) {
        final course =
            jsonDecode(
                  File('assets/courses/course_$name.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        for (final unit in course['units'] as List) {
          for (final lesson in unit['lessons'] as List) {
            expect(
              catalog
                  .recommend(course['id'] as String, lesson['id'] as String)
                  ?.courseId,
              course['id'],
              reason: lesson['id'] as String,
            );
            checked++;
          }
        }
      }
      expect(checked, 584);
    },
  );

  test(
    'unmapped lessons vary among earlier scenes at the same level',
    () async {
      final catalog = await ComedyCatalog.load();
      expect(catalog.recommend('beginner', 'u5l1')?.id, 'B01');
      expect(catalog.recommend('beginner', 'u24l1')?.id, 'B02');
      expect(catalog.recommend('beginner', 'u24l2')?.id, 'B03');
      expect(catalog.recommend('beginner', 'u24l3')?.id, 'B01');
      expect(catalog.recommend('intermediate', 'i_u4l1')?.id, 'I01');
    },
  );

  Future<void> open(WidgetTester tester, VoidCallback onFinished) async {
    await tester.runAsync(ComedyCatalog.load);
    // Exercise mounting while paused even though the scheduler suppresses its
    // ordinary frames; production initialization must still preserve pause.
    if (!tester.binding.framesEnabled) {
      tester.binding.scheduleForcedFrame();
    }
    await tester.pumpWidget(
      MaterialApp(
        home: PostLessonComedy(
          courseId: 'motherPattern',
          lessonId: 'mp_u3l1',
          strings: const S(UiLanguage.chinese),
          onFinished: onFinished,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      if (!tester.binding.framesEnabled) {
        tester.binding.scheduleForcedFrame();
      }
      await tester.pump();
      if (find.byType(AndroidView).evaluate().isNotEmpty ||
          find.text('I need a pen.').evaluate().isNotEmpty) {
        break;
      }
    }
  }

  testWidgets('skip exits once and cancels playback work', (tester) async {
    var finished = 0;
    await open(tester, () => finished++);
    await tester.tap(find.text(const S(UiLanguage.chinese).comedySkip));
    await tester.pump();
    await tester.tap(find.text(const S(UiLanguage.chinese).comedySkip));
    await tester.pump(const Duration(seconds: 60));
    expect(finished, 1);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('fallback pauses, steps, completes and replays without exiting', (
    tester,
  ) async {
    var finished = 0;
    await open(tester, () => finished++);
    expect(find.text('I need a pen.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('comedy-play-pause')));
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('I need a pen.'), findsOneWidget);
    await tester.tap(find.text('下一句'));
    await tester.pump();
    expect(find.text('Here you are.'), findsOneWidget);
    await tester.tap(find.text('上一句'));
    await tester.pump();
    expect(find.text('I need a pen.'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('下一句'));
      await tester.pump();
    }
    expect(finished, 0);
    expect(find.text('继续'), findsOneWidget);
    await tester.tap(find.text(const S(UiLanguage.chinese).comedyReplay).last);
    await tester.pump();
    expect(find.text('I need a pen.'), findsOneWidget);
    expect(finished, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 60));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('background pauses and resume waits for manual playback', (
    tester,
  ) async {
    await open(tester, () {});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('I need a pen.'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('I need a pen.'), findsOneWidget);
    expect(
      find.text(const S(UiLanguage.chinese).comedyBackgroundPaused),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('comedy-play-pause')));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Here you are.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('small screen and large text keep exit and captions usable', (
    tester,
  ) async {
    await tester.runAsync(ComedyCatalog.load);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: PostLessonComedy(
            courseId: 'zero',
            lessonId: 'z_u2l1',
            strings: const S(UiLanguage.english),
            onFinished: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(const S(UiLanguage.english).comedySkip), findsOneWidget);
    expect(find.text('One.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('native readiness times out with retry and an available exit', (
    tester,
  ) async {
    final native = _NativeHost();
    addTearDown(native.dispose);
    await open(tester, () {});
    expect(
      find.text(const S(UiLanguage.chinese).comedyLoading),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 13));
    expect(
      find.text(const S(UiLanguage.chinese).comedyLoadFailed),
      findsOneWidget,
    );
    await tester.tap(find.text(const S(UiLanguage.chinese).comedyRetry));
    await tester.pumpAndSettle();
    expect(
      find.text(const S(UiLanguage.chinese).comedyLoading),
      findsOneWidget,
    );
    expect(native.viewIds.length, 2);
    await native.event('ready');
    await tester.pump();
    expect(find.text(const S(UiLanguage.chinese).comedyLoading), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'player mounted while backgrounded waits for explicit Play',
    (tester) async {
      final native = _NativeHost();
      addTearDown(native.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await open(tester, () {});
      expect(
        find.text(const S(UiLanguage.chinese).comedyBackgroundPaused),
        findsOneWidget,
      );
      if (find.byType(AndroidView).evaluate().isNotEmpty) {
        expect(native.configurations.single['startPaused'], true);
        await native.event('ready');
        await tester.pump();
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 30));
      expect(
        find.text(const S(UiLanguage.chinese).comedyBackgroundPaused),
        findsOneWidget,
      );
      expect(native.commands, isNot(contains('play')));
      if (find.byType(AndroidView).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('comedy-native-resume')));
        await tester.pump();
        expect(native.commands, contains('play'));
      } else {
        expect(find.text('I need a pen.'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('comedy-play-pause')));
        await tester.pump(const Duration(seconds: 4));
        expect(find.text('Here you are.'), findsOneWidget);
      }
      expect(
        find.text(const S(UiLanguage.chinese).comedyBackgroundPaused),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'native loading retains background pause after resume and ready until Play',
    (tester) async {
      final native = _NativeHost();
      addTearDown(native.dispose);
      await open(tester, () {});
      expect(
        find.text(const S(UiLanguage.chinese).comedyLoading),
        findsOneWidget,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      final pausesBeforeReady = native.commands
          .where((command) => command == 'pause')
          .length;
      await native.event('ready');
      await tester.pump();
      expect(
        find.text(const S(UiLanguage.chinese).comedyBackgroundPaused),
        findsOneWidget,
      );
      expect(
        native.commands.where((command) => command == 'pause').length,
        greaterThan(pausesBeforeReady),
      );
      expect(native.commands, isNot(contains('play')));
      await tester.tap(find.byKey(const ValueKey('comedy-native-resume')));
      await tester.pump();
      expect(native.commands, contains('play'));
      expect(
        find.text(const S(UiLanguage.chinese).comedyBackgroundPaused),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native bridge completion, replay, background and skip remain controlled',
    (tester) async {
      final native = _NativeHost();
      addTearDown(native.dispose);
      var finished = 0;
      await open(tester, () => finished++);
      await native.event('ready');
      await tester.pump();
      await native.event('unexpected');
      await tester.pump();
      expect(
        find.text(const S(UiLanguage.chinese).comedyContinue),
        findsNothing,
      );
      await native.event('completed');
      await tester.pump();
      expect(
        find.text(const S(UiLanguage.chinese).comedyContinue),
        findsOneWidget,
      );
      expect(finished, 0);
      await tester.tap(find.text(const S(UiLanguage.chinese).comedyReplay));
      await tester.pump();
      expect(native.commands, contains('replay'));
      expect(
        find.text(const S(UiLanguage.chinese).comedyContinue),
        findsNothing,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(native.commands, contains('pause'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        find.text(const S(UiLanguage.chinese).comedyBackgroundPaused),
        findsOneWidget,
      );
      await native.event('error');
      await tester.pump();
      expect(
        find.text(const S(UiLanguage.chinese).comedyLoadFailed),
        findsOneWidget,
      );
      await tester.tap(find.text(const S(UiLanguage.chinese).comedySkip));
      await tester.tap(find.text(const S(UiLanguage.chinese).comedySkip));
      await tester.pump();
      expect(finished, 1);
      expect(native.commands, contains('stop'));
      await tester.pumpWidget(const SizedBox());
    },
  );
}

/// Only the platform transport is fake: the production Flutter shell creates
/// its real AndroidView and drives the actual per-view protocol.
class _NativeHost {
  _NativeHost() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      final args = call.arguments;
      if (call.method == 'create') {
        final id = (args as Map)['id'] as int;
        viewIds.add(id);
        final bytes = args['params'] as Uint8List;
        configurations.add(
          const StandardMessageCodec().decodeMessage(
                ByteData.sublistView(bytes),
              )
              as Map,
        );
        messenger.setMockMethodCallHandler(
          MethodChannel('globalvillage/comedy/$id'),
          (call) async {
            commands.add(call.method);
            return null;
          },
        );
        return id;
      }
      if (call.method == 'resize') {
        return {'width': (args as Map)['width'], 'height': args['height']};
      }
      return null;
    });
  }
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final viewIds = <int>[];
  final commands = <String>[];
  final configurations = <Map>[];

  Future<void> event(String event) async {
    final channel = MethodChannel('globalvillage/comedy/${viewIds.last}');
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall('event', event)),
      (_) {},
    );
  }

  void dispose() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final id in viewIds) {
      messenger.setMockMethodCallHandler(
        MethodChannel('globalvillage/comedy/$id'),
        null,
      );
    }
  }
}
