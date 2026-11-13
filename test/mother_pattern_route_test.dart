import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/app/router.dart';
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
