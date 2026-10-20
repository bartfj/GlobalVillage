import 'dart:io';

import 'package:english_village/app/providers.dart';
import 'package:english_village/core/services/sound_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/repositories/course_repository.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/sources/course_loader.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/features/lesson/dialogue_practice.dart';
import 'package:english_village/features/lesson/lesson_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'ui_test_overrides.dart';

class SilentSound implements SoundService {
  @override
  Future<void> playCorrect() async {}
  @override
  Future<void> playWrong() async {}
  @override
  void dispose() {}
}

class MemoryLearningStore extends LearningStore {
  MemoryLearningStore() : super(userKey: 'guest');
  final List<dynamic> _events = [];
  @override
  List<dynamic> get events => _events;
  @override
  Future<void> log(Map<String, dynamic> event) async {
    _events.add(event);
  }

  @override
  Future<void> recordAnswer({
    required String courseId,
    required String lessonId,
    required Exercise exercise,
    required bool correct,
    required bool first,
    required int elapsedMs,
    required String mode,
    bool skipped = false,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all dialogue tasks have unique choices and valid transfer expressions',
    () async {
      for (final track in [
        CourseTrack.zero,
        CourseTrack.beginner,
        CourseTrack.intermediate,
      ]) {
        final course = await CourseLoader().load(track);
        for (final unit in course.units) {
          final exercises = await buildDialoguePractice(unit);
          expect(exercises.length, 3);
          for (final e in exercises.take(2)) {
            expect(e.options.toSet().length, e.options.length, reason: e.id);
            expect(e.options, contains(e.answer));
          }
          expect(exercises.last.type, ExerciseType.translateInput);
          expect(
            unit.lessons.expand((l) => l.exercises).map((e) => e.sentence),
            contains(exercises.last.sentence),
            reason: unit.id,
          );
        }
      }
    },
  );

  testWidgets('practice completes and exits without updating course progress', (
    tester,
  ) async {
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('review_flow'),
    ))!;
    Hive.init(temp.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LessonProgressAdapter());
    }
    await tester.runAsync(() async {
      await Hive.openBox<LessonProgress>(ProgressStore.boxName);
      await Hive.openBox<String>(LearningStore.boxName);
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await Hive.close();
        await temp.delete(recursive: true);
      });
    });
    final course = (await tester.runAsync(
      () => CourseLoader().load(CourseTrack.zero),
    ))!;
    final store = MemoryLearningStore();
    const ex = Exercise(
      id: 'practice-input',
      type: ExerciseType.translateInput,
      prompt: '你好。',
      sentence: 'Hello.',
      answer: 'Hello.',
      options: [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseProvider.overrideWithValue(course),
          courseRepositoryProvider.overrideWithValue(CourseRepository(course)),
          learningStoreProvider.overrideWithValue(store),
          soundServiceProvider.overrideWithValue(SilentSound()),
          progressRepositoryProvider.overrideWithValue(
            ProgressRepository(
              store: const ProgressStore(userKey: 'guest'),
              course: course,
            ),
          ),
          uiStringsOverride,
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('开始复习'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LessonPage(
                      lessonId: 'practice',
                      mode: 'unit',
                      practiceLesson: Lesson(
                        id: 'p',
                        title: '复习',
                        exercises: [ex],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('开始复习'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('检查'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('练习完成'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('开始复习'), findsOneWidget);
    expect(Hive.box<LessonProgress>(ProgressStore.boxName).isEmpty, isTrue);
    expect(store.events.where((e) => e['kind'] == 'finish').length, 1);
    expect(tester.takeException(), isNull);
  });
}
