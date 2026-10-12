import 'dart:io';

import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/data/sources/course_loader.dart';
import 'package:english_village/data/sources/settings_store.dart';
import 'package:english_village/features/learning_path/widgets/course_selector.dart';
import 'package:english_village/features/lesson/widgets/exercise_widget_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../tool/generate_language_courses.dart';

class LanguageTestAuth extends StateNotifier<AuthState>
    implements AuthController {
  LanguageTestAuth() : super(const AuthState(userKey: 'alice'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryLanguageSettings extends SettingsStore {
  CourseTrack track = CourseTrack.beginner;
  final remembered = <LearningLanguage, CourseTrack>{};
  @override
  CourseTrack getTrack(String userKey) => track;
  @override
  Future<void> setTrack(String userKey, CourseTrack value) async {
    track = value;
    remembered[value.language] = value;
  }

  @override
  CourseTrack getLanguageTrack(String userKey, LearningLanguage language) =>
      remembered[language] ??
      CourseTrack.values.firstWhere((t) => t.language == language);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'language courses have explicit tokens, strict answers and no audio tasks',
    () async {
      for (final track in [CourseTrack.chinese, CourseTrack.sanskrit]) {
        final course = await CourseLoader().load(track);
        expect(course.orderedLessons.length, 16);
        expect(course.units.length, 4);
        for (final lesson in course.orderedLessons) {
          expect(lesson.exercises.length, 9);
          for (final e in lesson.exercises) {
            expect(e.language, track.language);
            expect(
              e.type,
              anyOf(
                ExerciseType.translateChoice,
                ExerciseType.wordBank,
                ExerciseType.translateInput,
              ),
            );
            expect(e.accepts(e.answer), isTrue);
            if (e.type == ExerciseType.wordBank) {
              expect(e.tokens.join(e.tokenSeparator), e.answer);
            }
            if (e.type == ExerciseType.translateChoice) {
              expect(e.options.toSet().length, 4);
              expect(e.options, contains(e.answer));
            }
          }
        }
      }
      const sanskrit = Exercise(
        id: 'sa',
        type: ExerciseType.translateInput,
        prompt: '',
        sentence: 'ā',
        options: [],
        answer: 'ā',
        language: LearningLanguage.sanskrit,
      );
      expect(sanskrit.accepts('a\u0304'), isTrue);
      expect(sanskrit.accepts('a'), isFalse);
      expect(sanskrit.accepts('Ā'), isFalse);
      // ASCII keyboard aliases still respect strict distinctions.
      expect(sanskrit.accepts('aa'), isTrue);
      const retroflex = Exercise(
        id: 'sa-ta',
        type: ExerciseType.translateInput,
        prompt: '',
        sentence: 'ṭa',
        options: [],
        answer: 'ṭa',
        language: LearningLanguage.sanskrit,
      );
      expect(retroflex.accepts('Ta'), isTrue);
      expect(retroflex.accepts('ta'), isFalse);
      const word = Exercise(
        id: 'sa-rama',
        type: ExerciseType.translateInput,
        prompt: '',
        sentence: 'rāmaḥ',
        options: [],
        answer: 'rāmaḥ',
        language: LearningLanguage.sanskrit,
      );
      expect(word.accepts('raamaH'), isTrue);
      expect(word.accepts('ramaha'), isFalse);
      const chinese = Exercise(
        id: 'zh',
        type: ExerciseType.translateInput,
        prompt: '',
        sentence: 'mǎ',
        options: [],
        answer: 'mǎ',
        language: LearningLanguage.chinese,
      );
      expect(chinese.accepts('ma\u030c'), isTrue);
      expect(chinese.accepts('ma'), isFalse);
      expect(chinese.accepts('ma3'), isTrue);
      expect(chinese.accepts('ma4'), isFalse);
      const nu = Exercise(
        id: 'zh-nu',
        type: ExerciseType.translateInput,
        prompt: '',
        sentence: 'nǚ',
        options: [],
        answer: 'nǚ',
        language: LearningLanguage.chinese,
      );
      expect(nu.accepts('nv3'), isTrue);
      expect(nu.accepts('lv'), isFalse);
      final generated = generateLanguageCourses(write: false);
      for (final entry in generated.entries) {
        final onDisk = File(entry.key)
            .readAsStringSync()
            .replaceAll('\r\n', '\n');
        expect(onDisk, entry.value);
      }
    },
  );

  group('account language preferences', () {
    late Directory temp;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('language_settings');
      Hive.init(temp.path);
      await Hive.openBox<String>(SettingsStore.boxName);
    });
    tearDown(() async {
      await Hive.close();
      await temp.delete(recursive: true);
    });

    test(
      'legacy track, per-language memory and accounts are preserved',
      () async {
        final settings = SettingsStore();
        await Hive.box<String>(
          SettingsStore.boxName,
        ).put('alice|track', 'elementary');
        expect(settings.getTrack('alice'), CourseTrack.beginner);
        await settings.setTrack('alice', CourseTrack.intermediate);
        await settings.setTrack('alice', CourseTrack.chinese);
        expect(settings.getTrack('alice'), CourseTrack.chinese);
        expect(
          settings.getLanguageTrack('alice', LearningLanguage.english),
          CourseTrack.intermediate,
        );
        expect(
          settings.getLanguageTrack('alice', LearningLanguage.chinese),
          CourseTrack.chinese,
        );
        expect(settings.getTrack('bob'), CourseTrack.beginner);
        await Hive.box<String>(
          SettingsStore.boxName,
        ).put('alice|track|sanskrit', 'bad');
        expect(
          settings.getLanguageTrack('alice', LearningLanguage.sanskrit),
          CourseTrack.sanskrit,
        );
      },
    );
  });

  testWidgets('selector cancellation and course commit on narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => LanguageTestAuth()),
        settingsStoreProvider.overrideWithValue(MemoryLanguageSettings()),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(allCoursesProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showCourseSelector(context, ref),
                child: const Text('切换'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('切换'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文 Chinese'));
    await tester.pumpAndSettle();
    expect(container.read(selectedTrackProvider), CourseTrack.beginner);
    Navigator.pop(tester.element(find.text('系统课程')));
    await tester.pumpAndSettle();
    expect(container.read(selectedTrackProvider), CourseTrack.beginner);
    await tester.tap(find.text('切换'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文 Chinese'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('普通话入门'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(container.read(selectedTrackProvider), CourseTrack.chinese);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Chinese tokens join without spaces and Sanskrit support renders',
    (tester) async {
      final course = (await tester.runAsync(
        () => CourseLoader().load(CourseTrack.chinese),
      ))!;
      final e = course.units[1].lessons.first.exercises[4];
      var answer = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: buildExerciseWidget(
                exercise: e,
                enabled: true,
                checked: false,
                currentAnswer: '',
                onChanged: (value) => answer = value,
                questionKey: const ValueKey('zh'),
              ),
            ),
          ),
        ),
      );
      for (final token in e.tokens) {
        await tester.tap(find.widgetWithText(ActionChip, token));
        await tester.pump();
      }
      expect(answer, e.answer);
      final sa = (await tester.runAsync(
        () => CourseLoader().load(CourseTrack.sanskrit),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: buildExerciseWidget(
                exercise: sa.units.first.lessons.first.exercises.first,
                enabled: true,
                checked: false,
                currentAnswer: '',
                onChanged: (_) {},
                questionKey: const ValueKey('sa'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('अ'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('special character bar inserts into translate input', (
    tester,
  ) async {
    final sa = (await tester.runAsync(
      () => CourseLoader().load(CourseTrack.sanskrit),
    ))!;
    final e = sa.units.first.lessons.first.exercises.firstWhere(
      (ex) => ex.type == ExerciseType.translateInput && ex.answer == 'ī',
    );
    var answer = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: buildExerciseWidget(
              exercise: e,
              enabled: true,
              checked: false,
              currentAnswer: '',
              onChanged: (value) => answer = value,
              questionKey: const ValueKey('sa-input'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ActionChip, 'ī'));
    await tester.pump();
    expect(answer, 'ī');
    expect(e.accepts(answer), isTrue);
    await tester.tap(find.widgetWithText(ActionChip, 'ḥ'));
    await tester.pump();
    expect(answer, 'īḥ');
    expect(tester.takeException(), isNull);
  });
}
