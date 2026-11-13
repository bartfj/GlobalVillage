import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/app/router.dart';
import 'package:english_village/core/services/tts_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/repositories/course_repository.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/data/sources/mother_pattern_store.dart';
import 'package:english_village/features/lesson/lesson_page.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_page.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_providers.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_speech.dart';
import 'mother_pattern_completion_test.dart'
    show PatternProgress, PatternRewards;
import 'mother_pattern_page_test.dart' show PatternVoice, PatternTrack;
import 'mother_pattern_speech_test.dart'
    show FakePatternRecorder, FakePatternRecognizer;
import 'ui_test_overrides.dart';
import 'tts_cancellation_test.dart'
    show ControlledAudioPlayer, ControlledSpeechEngine, ControlledAssets;

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth() : super(const AuthState(userKey: 'alice'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mp-route');
    Hive.init(temp.path);
    await Hive.openBox<String>(LearningStore.boxName);
  });
  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  testWidgets(
    'same-course replacement cancels old audio and PCM then saves only the new lesson',
    (tester) async {
      final course = Course.fromJson(
        jsonDecode(
          File(CourseTrack.motherPattern.assetPath).readAsStringSync(),
        ),
      );
      final old = course.orderedLessons.first;
      final next = course.orderedLessons[1];
      final learning = LearningStore(userKey: 'alice');
      final store = MotherPatternStore(
        userKey: 'alice',
        learningStore: learning,
      );
      final progress = PatternProgress();
      final rewards = PatternRewards(course);
      final native = ControlledAudioPlayer()..sourceWait = Completer<void>();
      final voice = TtsService(
        player: native,
        tts: ControlledSpeechEngine(),
        assets: ControlledAssets(),
      );
      final recorders = <FakePatternRecorder>[];
      final container = ProviderContainer(
        overrides: [
          uiStringsOverride,
          authProvider.overrideWith((ref) => _Auth()),
          selectedTrackProvider.overrideWith((ref) => PatternTrack()),
          courseProvider.overrideWithValue(course),
          courseRepositoryProvider.overrideWithValue(CourseRepository(course)),
          progressRepositoryProvider.overrideWithValue(progress),
          rewardRepositoryProvider.overrideWithValue(rewards),
          learningStoreProvider.overrideWithValue(learning),
          motherPatternStoreProvider.overrideWithValue(store),
          ttsServiceProvider.overrideWithValue(voice),
          motherPatternSpeechFactoryProvider.overrideWithValue(() {
            final recorder = FakePatternRecorder();
            recorders.add(recorder);
            return MotherPatternSpeech(
              recorder: recorder,
              recognizer: FakePatternRecognizer(),
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(voice.dispose);
      final router = container.read(goRouterProvider);
      router.go('/lesson/${old.id}');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String key) async {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
      }

      Future<void> answer(Exercise e) async {
        if (e.type == ExerciseType.listeningChoice) {
          await tap('option-${e.id}-${e.options.indexOf(e.answer)}');
        } else if (e.type == ExerciseType.wordBank) {
          for (var i = 0; i < e.tokens.length; i++) {
            await tap('token-${e.id}-$i');
          }
        } else {
          if (e.type == ExerciseType.speaking) {
            await tap('typed-fallback');
          }
          await tester.enterText(
            find.byKey(const ValueKey('pattern-input')),
            e.answer,
          );
        }
        await tap('pattern-check');
        await tap('pattern-next');
      }

      await tap('dialogue-audio-0');
      await tap('pattern-start');
      for (final e in old.exercises.take(4)) {
        await answer(e);
      }
      await tap('speech-start');
      expect(recorders.first.recording, true);
      router.go('/lesson/${next.id}');
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        native.sourceWait!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(find.text(next.patternLesson!.frame), findsOneWidget);
      expect(find.text(old.patternLesson!.frame), findsNothing);
      expect(recorders.length, 2);
      expect(recorders.first.recording, false);
      expect(recorders.first.disposals, 1);
      expect(native.starts, isEmpty);
      await tap('pattern-start');
      for (final e in next.exercises) {
        await answer(e);
      }
      expect(store.latestSummary(course.id, old.patternLesson!), isNull);
      expect(store.latestSummary(course.id, next.patternLesson!), isNotNull);
      expect(progress.completed.contains(old.id), false);
      expect(progress.completed.contains(next.id), true);
    },
  );
  for (final track in [CourseTrack.motherPattern, CourseTrack.beginner]) {
    testWidgets(
      'lesson route dispatches ${track.id} by selected course identity',
      (tester) async {
        final course = Course.fromJson(
          jsonDecode(File(track.assetPath).readAsStringSync()),
        );
        final selected = PatternTrack()..change(track);
        final learning = LearningStore(userKey: 'alice');
        final container = ProviderContainer(
          overrides: [
            uiStringsOverride,
            authProvider.overrideWith((ref) => _Auth()),
            selectedTrackProvider.overrideWith((ref) => selected),
            courseProvider.overrideWithValue(course),
            courseRepositoryProvider.overrideWithValue(
              CourseRepository(course),
            ),
            progressRepositoryProvider.overrideWithValue(PatternProgress()),
            rewardRepositoryProvider.overrideWithValue(PatternRewards(course)),
            learningStoreProvider.overrideWithValue(
              track == CourseTrack.beginner ? null : learning,
            ),
            motherPatternStoreProvider.overrideWithValue(
              MotherPatternStore(userKey: 'alice', learningStore: learning),
            ),
            ttsServiceProvider.overrideWithValue(PatternVoice()),
            motherPatternSpeechFactoryProvider.overrideWithValue(
              () => MotherPatternSpeech(
                recorder: FakePatternRecorder(),
                recognizer: FakePatternRecognizer(),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final lesson = track == CourseTrack.beginner
            ? course.lessonById('u1l2')!
            : course.orderedLessons.first;
        final router = container.read(goRouterProvider);
        router.go('/lesson/${lesson.id}');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(MotherPatternPage),
          track == CourseTrack.motherPattern ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(LessonPage),
          track == CourseTrack.beginner ? findsOneWidget : findsNothing,
        );
        if (track == CourseTrack.beginner) {
          expect(find.text('My name is …'), findsNothing);
        }
      },
    );
  }
}
