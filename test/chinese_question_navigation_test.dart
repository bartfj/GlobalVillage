import 'dart:convert';
import 'dart:io';

import 'package:english_village/app/providers.dart';
import 'package:english_village/app/selected_track_controller.dart';
import 'package:english_village/core/services/sound_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/models/skill_practice.dart';
import 'package:english_village/data/repositories/course_repository.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/data/sources/skill_practice_loader.dart';
import 'package:english_village/features/learning_path/review_page.dart';
import 'package:english_village/features/lesson/lesson_page.dart';
import 'package:english_village/features/lesson/widgets/language_exercise_widget.dart';
import 'package:english_village/features/skill_practice/skill_practice_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'ui_test_overrides.dart';

const _first = Exercise(
  id: 'zh-first',
  type: ExerciseType.translateChoice,
  prompt: '第一道题',
  sentence: '请问图书馆的详细地址是哪里？',
  answer: '请问图书馆的详细地址是哪里？',
  options: [
    '图书馆什么时候开始营业？',
    '附近有去博物馆的公共汽车吗？',
    '请问从这里走到学校要多久？',
    '请问图书馆的详细地址是哪里？',
  ],
  language: LearningLanguage.chinese,
);

const _second = Exercise(
  id: 'zh-second',
  type: ExerciseType.translateChoice,
  prompt: '第二道题',
  sentence: '请问下一班到上海的火车几点开？',
  answer: '请问下一班到上海的火车几点开？',
  options: [
    '请问下一班到上海的火车几点开？',
    '你知道附近有没有空房间吗？',
    '请问这家饭店什么时候营业？',
    '附近的车站可以在哪里买票？',
  ],
  language: LearningLanguage.chinese,
);

const _lesson = Lesson(
  id: 'zh-sample',
  title: '示例',
  exercises: [_first, _second],
);
const _course = Course(
  id: 'chinese',
  title: '普通话入门',
  language: LearningLanguage.chinese,
  units: [
    Unit(id: 'zh-unit', title: '示例', description: '', lessons: [_lesson]),
  ],
);

class _SilentSound implements SoundService {
  @override
  void dispose() {}

  @override
  Future<void> playCorrect() async {}

  @override
  Future<void> playWrong() async {}
}

class _ChinesePracticeLoader extends SkillPracticeLoader {
  @override
  Future<SkillPracticeBank> load(SkillPracticeKind skill) async =>
      const SkillPracticeBank(
        skill: SkillPracticeKind.chineseCharacters,
        title: '汉字识读',
        chapters: [
          SkillPracticeChapter(
            id: 'zh-test',
            title: '示例',
            exercises: [_first, _second],
          ),
        ],
      );

  @override
  List<Exercise> pickSession(List<Exercise> exercises, {int limit = 10}) =>
      exercises.take(limit).toList();
}

class _ChineseTrack extends StateNotifier<CourseTrack>
    implements SelectedTrackController {
  _ChineseTrack() : super(CourseTrack.chineseZero);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReviewStore extends LearningStore {
  _ReviewStore() : super(userKey: 'guest');

  // The real store records the seeded wrong answer. Ignore route telemetry in
  // the widget's fake-async zone so Hive can close after the test.
  @override
  Future<void> log(Map<String, dynamic> event) async {}
}

Widget _app(Widget page, {Course course = _course, LearningStore? store}) =>
    ProviderScope(
      overrides: [
        courseProvider.overrideWithValue(course),
        courseRepositoryProvider.overrideWithValue(CourseRepository(course)),
        progressRepositoryProvider.overrideWithValue(
          ProgressRepository(
            store: const ProgressStore(userKey: 'guest'),
            course: course,
          ),
        ),
        selectedTrackProvider.overrideWith((_) => _ChineseTrack()),
        checkInRepositoryProvider.overrideWithValue(null),
        learningStoreProvider.overrideWithValue(store),
        soundServiceProvider.overrideWithValue(_SilentSound()),
        uiStringsOverride,
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: page,
      ),
    );

void main() {
  for (final scenario in ['课程', '复习', '专项']) {
    testWidgets('$scenario中文题可滚动访问四项，换题时回到题干', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 560);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final page = switch (scenario) {
        '课程' => LessonPage(lessonId: _lesson.id),
        '复习' => const LessonPage(
          lessonId: 'practice',
          practiceLesson: _lesson,
          mode: 'review',
        ),
        _ => SkillPracticePage(
          skill: SkillPracticeKind.chineseCharacters,
          chapterId: 'zh-test',
          loader: _ChinesePracticeLoader(),
        ),
      };
      await tester.pumpWidget(_app(page));
      await tester.pumpAndSettle();
      if (scenario == '课程') {
        await tester.tap(find.text('开始练习'));
        await tester.pumpAndSettle();
      }

      for (final option in _first.options) {
        final label = find.text(option);
        await tester.ensureVisible(label);
        await tester.pumpAndSettle();
        expect(label.hitTestable(), findsOneWidget);
      }
      await tester.tap(find.text(_first.answer));
      await tester.pumpAndSettle();
      await tester.tap(find.text('检查'));
      await tester.pumpAndSettle();
      double offset() => tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;
      expect(offset(), greaterThan(0));

      await tester.tap(find.text('继续'));
      await tester.pumpAndSettle();
      expect(offset(), 0);
      expect(find.text(_second.prompt).hitTestable(), findsOneWidget);
      expect(find.text(_second.options.first).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'an existing Chinese mistake reopens the corrected four-choice question',
    (tester) async {
      final course = Course.fromJson(
        jsonDecode(
              File(
                'assets/courses/course_chinese_zero.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      const oldQuestion = Exercise(
        id: 'zh_u1l1e5',
        type: ExerciseType.wordBank,
        prompt: 'Write tone-marked pinyin: mother (pinyin, first tone)',
        sentence: 'mā',
        answer: 'mā',
        options: [],
        tokens: ['mā'],
        tokenSeparator: '',
        language: LearningLanguage.chinese,
      );
      final store = _ReviewStore();
      await tester.runAsync(() async {
        final temp = await Directory.systemTemp.createTemp(
          'chinese_question_review',
        );
        Hive.init(temp.path);
        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(LessonProgressAdapter());
        }
        addTearDown(() async {
          await Hive.close();
          await temp.delete(recursive: true);
        });
        await Hive.openBox<String>(LearningStore.boxName);
        await Hive.openBox<LessonProgress>(ProgressStore.boxName);
        await store.recordAnswer(
          courseId: course.id,
          lessonId: 'zh_u1l1',
          exercise: oldQuestion,
          correct: false,
          first: true,
          elapsedMs: 1000,
          mode: 'lesson',
        );
      });

      await tester.pumpWidget(
        _app(const ReviewPage(), course: course, store: store),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('今日错题'));
      await tester.pumpAndSettle();
      final question = tester
          .widget<LanguageExerciseWidget>(find.byType(LanguageExerciseWidget))
          .exercise;
      expect(question.id, oldQuestion.id);
      expect(question.type, ExerciseType.translateChoice);
      expect(question.options.toSet(), {'mā', 'má', 'mǎ', 'mà'});
    },
  );
}
