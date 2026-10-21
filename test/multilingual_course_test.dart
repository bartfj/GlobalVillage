import 'dart:io';

import 'package:english_village/app/app_strings.dart';
import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/core/services/tts_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/sources/course_loader.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/data/sources/settings_store.dart';
import 'package:english_village/features/learning_path/learning_path_page.dart';
import 'package:english_village/features/learning_path/widgets/course_selector.dart';
import 'package:english_village/features/lesson/widgets/exercise_widget_builder.dart';
import 'package:english_village/features/lesson/widgets/lesson_study_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../tool/generate_language_courses.dart';
import 'ui_test_overrides.dart';

final _hanzi = RegExp(r'[\u4e00-\u9fff]');

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

  // 界面语言设置不依赖 Hive；默认固定中文界面，避免切中文课后标签变英文。
  String? uiLanguageOverrideValue = 'chinese';
  bool uiLanguagePromptedValue = true;
  @override
  String? get uiLanguageOverride => uiLanguageOverrideValue;
  @override
  Future<void> setUiLanguageOverride(String? value) async {
    uiLanguageOverrideValue = value;
  }

  @override
  bool get uiLanguagePrompted => uiLanguagePromptedValue;
  @override
  Future<void> setUiLanguagePrompted() async {
    uiLanguagePromptedValue = true;
  }
}

class CompletedIds implements ProgressStore {
  CompletedIds(this.ids);
  final Set<String> ids;

  @override
  LessonProgress? get(String lessonId) => ids.contains(lessonId)
      ? LessonProgress(
          lessonId: lessonId,
          completed: true,
          score: 100,
          correctCount: 9,
          totalCount: 9,
          completedAt: DateTime(2026),
        )
      : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 记录发音请求，避免测试触发真实平台 TTS。
class RecordingTts implements TtsService {
  RecordingTts({this.result = true});

  bool result;
  final exercises = <Exercise>[];
  final spoken = <String>[];
  final languages = <LearningLanguage>[];

  @override
  Future<bool> speakExercise(Exercise exercise) async {
    exercises.add(exercise);
    return result;
  }

  @override
  Future<bool> speak(
    String text, {
    LearningLanguage language = LearningLanguage.english,
  }) async {
    spoken.add(text);
    languages.add(language);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'language courses keep strict answers; only Chinese starter uses audio',
    () async {
      const expected = {
        CourseTrack.chineseZero: (units: 1, lessons: 4),
        CourseTrack.chinese: (units: 3, lessons: 12),
        CourseTrack.sanskritZero: (units: 2, lessons: 8),
        CourseTrack.sanskrit: (units: 2, lessons: 8),
      };
      for (final entry in expected.entries) {
        final track = entry.key;
        final course = await CourseLoader().load(track);
        expect(course.orderedLessons.length, entry.value.lessons);
        expect(course.units.length, entry.value.units);
        for (final lesson in course.orderedLessons) {
          expect(lesson.exercises.length, 9);
          var listening = 0;
          for (final e in lesson.exercises) {
            expect(e.language, track.language);
            if (e.type == ExerciseType.listeningChoice) {
              listening++;
              expect(track, CourseTrack.chineseZero);
              // support 存汉字供 TTS 朗读，选项仍是带声调拼音。
              expect(e.support, isNotNull);
              expect(_hanzi.hasMatch(e.support!), isTrue);
              expect(e.options.toSet().length, 4);
              expect(e.options, contains(e.answer));
              continue;
            }
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
          final expectedListening = track == CourseTrack.chineseZero ? 1 : 0;
          expect(listening, expectedListening);
          if (expectedListening == 1) {
            // 听辨固定为每课第 2 题，学习卡之后先听音再辨调。
            expect(lesson.exercises[1].type, ExerciseType.listeningChoice);
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
        final onDisk = File(
          entry.key,
        ).readAsStringSync().replaceAll('\r\n', '\n');
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
        // 非法记忆值回退到该语言的默认（零基础）课程。
        expect(
          settings.getLanguageTrack('alice', LearningLanguage.sanskrit),
          CourseTrack.sanskritZero,
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
    // 面板只选语言，不再展开系统课程列表。
    expect(find.text('系统课程'), findsNothing);
    Navigator.pop(tester.element(find.text('学习语言')));
    await tester.pumpAndSettle();
    expect(container.read(selectedTrackProvider), CourseTrack.beginner);
    // 英语记忆切到中级，验证语言切换恢复各语言上次课程。
    await container
        .read(selectedTrackProvider.notifier)
        .select(CourseTrack.intermediate);
    await tester.tap(find.text('切换'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文 Chinese'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(container.read(selectedTrackProvider), CourseTrack.chineseZero);
    await tester.tap(find.text('切换'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('英语'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(container.read(selectedTrackProvider), CourseTrack.intermediate);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to Chinese asks about the English UI after closing', (
    tester,
  ) async {
    final settings = MemoryLanguageSettings()
      ..uiLanguageOverrideValue = null
      ..uiLanguagePromptedValue = false;
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => LanguageTestAuth()),
        settingsStoreProvider.overrideWithValue(settings),
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
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // 选择面板先关闭，不应残留转圈状态；随后才出现英文界面提示。
    expect(find.text('学习语言'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('English interface on'), findsOneWidget);
    expect(container.read(selectedTrackProvider), CourseTrack.chineseZero);
    expect(container.read(uiLanguageProvider), UiLanguage.english);

    await tester.tap(find.text('Switch to Chinese'));
    await tester.pumpAndSettle();
    expect(settings.uiLanguageOverrideValue, 'chinese');
    expect(container.read(uiLanguageProvider), UiLanguage.chinese);
    expect(settings.uiLanguagePromptedValue, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starter completion offers the intro course', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final zero = (await tester.runAsync(
      () => CourseLoader().load(CourseTrack.chineseZero),
    ))!;
    final intro = (await tester.runAsync(
      () => CourseLoader().load(CourseTrack.chinese),
    ))!;
    final settings = MemoryLanguageSettings()..track = CourseTrack.chineseZero;
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => LanguageTestAuth()),
        settingsStoreProvider.overrideWithValue(settings),
        progressStoreProvider.overrideWithValue(
          CompletedIds({for (final lesson in zero.orderedLessons) lesson.id}),
        ),
        allCoursesProvider.overrideWith((ref) async => [zero, intro]),
        uiStringsOverride,
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(allCoursesProvider.future));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LearningPathPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('零基础课程已完成 · 接下来学普通话入门'), findsOneWidget);
    expect(find.text('进入普通话入门'), findsOneWidget);

    await tester.tap(find.text('进入普通话入门'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(container.read(selectedTrackProvider), CourseTrack.chinese);
    expect(settings.track, CourseTrack.chinese);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Chinese tokens join without spaces and Sanskrit support renders',
    (tester) async {
      final course = (await tester.runAsync(
        () => CourseLoader().load(CourseTrack.chinese),
      ))!;
      final e = course.units[0].lessons.first.exercises[4];
      var answer = '';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [uiStringsOverride],
          child: MaterialApp(
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
        ),
      );
      for (final token in e.tokens) {
        await tester.tap(find.widgetWithText(ActionChip, token));
        await tester.pump();
      }
      expect(answer, e.answer);
      final sa = (await tester.runAsync(
        () => CourseLoader().load(CourseTrack.sanskritZero),
      ))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [uiStringsOverride],
          child: MaterialApp(
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
      () => CourseLoader().load(CourseTrack.sanskritZero),
    ))!;
    final e = sa.units.first.lessons.first.exercises.firstWhere(
      (ex) => ex.type == ExerciseType.translateInput && ex.answer == 'ī',
    );
    var answer = '';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [uiStringsOverride],
        child: MaterialApp(
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

  test('Sanskrit corpus keeps letter dependencies across units', () async {
    final zero = await CourseLoader().load(CourseTrack.sanskritZero);
    final course = await CourseLoader().load(CourseTrack.sanskrit);
    // 零基础课先教元音（单元 1）与辅音拼读（单元 2），入门课承接词句。
    final units = [...zero.units, ...course.units];
    expect(units[1].lessons.first.exercises.first.answer, 'ka');
    // 单元 3 的词只用已教字母；namaste 为标注“整体认读”的例外。
    final unit3 = units[2];
    final answers = {
      for (final lesson in unit3.lessons)
        for (final e in lesson.exercises) e.answer,
    };
    expect(
      answers,
      containsAll([
        'namaste',
        'mama',
        'nāma',
        'mama nāma',
        'āma',
        'kāka',
        'naṭa',
        'maṭa',
      ]),
    );
    final sightWord = unit3.lessons.first.exercises.firstWhere(
      (e) => e.answer == 'namaste',
    );
    expect(sightWord.prompt, contains('整体认读'));
    // 单元 4 做人称动词入门，复现单元 3 的 naṭa（主格 naṭaḥ）。
    final unit4Answers = {
      for (final lesson in units[3].lessons)
        for (final e in lesson.exercises) e.answer,
    };
    expect(
      unit4Answers,
      containsAll(['ahaṃ paṭhāmi', 'tvam paṭhasi', 'naṭaḥ paṭhati']),
    );
  });

  testWidgets('lesson study card lists core items before exercises', (
    tester,
  ) async {
    final zero = (await tester.runAsync(
      () => CourseLoader().load(CourseTrack.sanskritZero),
    ))!;
    final course = (await tester.runAsync(
      () => CourseLoader().load(CourseTrack.sanskrit),
    ))!;
    final lesson = [...zero.units, ...course.units][2].lessons.first;
    final items = lessonStudyItems(lesson);
    // 每课 4 条核心内容，去重且保留顺序；含义从题干提取。
    expect(items.length, 4);
    expect(items.first.text, 'namaste');
    expect(items.first.support, 'नमस्ते');
    expect(items.first.meaning, '向你致敬（问候，整体认读）');

    var started = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [uiStringsOverride],
        child: MaterialApp(
          home: LessonStudyCard(lesson: lesson, onStart: () => started = true),
        ),
      ),
    );
    expect(find.text('先看本课内容，再开始练习'), findsOneWidget);
    expect(find.text('नमस्ते'), findsOneWidget);
    expect(find.text('namaste'), findsOneWidget);
    expect(find.text('向你致敬（问候，整体认读）'), findsOneWidget);
    await tester.tap(find.text('开始练习'));
    expect(started, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('speakableText picks Chinese characters instead of pinyin', () {
    const toneExercise = Exercise(
      id: 'zh-tone',
      type: ExerciseType.listeningChoice,
      prompt: '',
      sentence: 'má',
      options: ['mā', 'má', 'mǎ', 'mà'],
      answer: 'má',
      language: LearningLanguage.chinese,
      support: '麻',
    );
    expect(TtsService.speakableText(toneExercise), '麻');
    const hanziExercise = Exercise(
      id: 'zh-hanzi',
      type: ExerciseType.translateChoice,
      prompt: '',
      sentence: '你好',
      options: ['Hello'],
      answer: '你好',
      language: LearningLanguage.chinese,
      support: 'nǐ hǎo',
    );
    expect(TtsService.speakableText(hanziExercise), '你好');
    const sanskrit = Exercise(
      id: 'sa',
      type: ExerciseType.translateChoice,
      prompt: '',
      sentence: 'namaste',
      options: ['你好'],
      answer: 'namaste',
      language: LearningLanguage.sanskrit,
    );
    // 梵文没有可靠语音，不交给 TTS。
    expect(TtsService.speakableText(sanskrit), isNull);
  });

  testWidgets('Chinese listening exercise auto-plays and replays the tone', (
    tester,
  ) async {
    final course = (await tester.runAsync(
      () => CourseLoader().load(CourseTrack.chineseZero),
    ))!;
    final exercise = course.orderedLessons.first.exercises[1];
    expect(exercise.type, ExerciseType.listeningChoice);
    final tts = RecordingTts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWithValue(tts),
          uiStringsOverride,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: buildExerciseWidget(
                exercise: exercise,
                enabled: true,
                checked: false,
                currentAnswer: '',
                onChanged: (_) {},
                questionKey: const ValueKey('zh-listening'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Listen and choose the tone you hear'), findsOneWidget);
    expect(tts.exercises, [exercise]);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(tts.exercises.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese listening failure shows a localized hint', (
    tester,
  ) async {
    final course = (await tester.runAsync(
      () => CourseLoader().load(CourseTrack.chineseZero),
    ))!;
    final exercise = course.orderedLessons.first.exercises[1];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWithValue(RecordingTts(result: false)),
          uiStringsOverride,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: buildExerciseWidget(
                exercise: exercise,
                enabled: true,
                checked: false,
                currentAnswer: '',
                onChanged: (_) {},
                questionKey: const ValueKey('zh-listening-fail'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('语音播放失败，请检查系统中文语音包与媒体音量后重试。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese study card plays each item as characters', (
    tester,
  ) async {
    final course = (await tester.runAsync(
      () => CourseLoader().load(CourseTrack.chineseZero),
    ))!;
    final lesson = course.orderedLessons.first;
    final tts = RecordingTts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWithValue(tts),
          uiStringsOverride,
        ],
        child: MaterialApp(
          home: LessonStudyCard(lesson: lesson, onStart: () {}),
        ),
      ),
    );

    final buttons = find.byIcon(Icons.volume_up_rounded);
    expect(buttons, findsNWidgets(4));

    await tester.tap(buttons.first);
    await tester.pump();
    expect(tts.spoken, ['妈']);
    expect(tts.languages, [LearningLanguage.chinese]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese study card reports failed playback', (tester) async {
    final course = (await tester.runAsync(
      () => CourseLoader().load(CourseTrack.chineseZero),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWithValue(RecordingTts(result: false)),
          uiStringsOverride,
        ],
        child: MaterialApp(
          home: LessonStudyCard(
            lesson: course.orderedLessons.first,
            onStart: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.volume_up_rounded).first);
    await tester.pump();
    await tester.pump();
    expect(find.text('语音播放失败，请检查系统中文语音包与媒体音量后重试。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
