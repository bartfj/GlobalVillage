import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:english_village/app/providers.dart';
import 'package:english_village/core/services/sound_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/models/skill_practice.dart';
import 'package:english_village/data/repositories/course_repository.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/sources/course_loader.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/data/sources/skill_practice_loader.dart';
import 'package:english_village/features/lesson/widgets/tappable_phonetic_text.dart';
import 'package:english_village/features/skill_practice/skill_practice_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

const _allowedTypes = {
  SkillPracticeKind.pronunciation: {
    ExerciseType.listeningChoice,
    ExerciseType.listeningWordBank,
    ExerciseType.dictation,
    ExerciseType.speaking,
  },
  SkillPracticeKind.vocabulary: {
    ExerciseType.matchPairs,
    ExerciseType.fillBlank,
    ExerciseType.translateChoice,
    ExerciseType.wordBank,
  },
  SkillPracticeKind.speaking: {
    ExerciseType.speaking,
    ExerciseType.translateInput,
  },
  SkillPracticeKind.chineseTones: {ExerciseType.translateChoice},
  SkillPracticeKind.chineseCharacters: {ExerciseType.translateChoice},
  SkillPracticeKind.sanskritLetters: {ExerciseType.translateChoice},
  SkillPracticeKind.sanskritVowels: {ExerciseType.translateChoice},
  SkillPracticeKind.sanskritYoga: {ExerciseType.translateChoice},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('skill practice banks exist with typed exercises', () {
    for (final skill in SkillPracticeKind.values) {
      final file = File('assets/practice/${skill.name}.json');
      expect(file.existsSync(), isTrue, reason: file.path);
      final bank = SkillPracticeBank.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(bank.skill, skill);
      expect(bank.exercises.length, inInclusiveRange(10, 60));
      for (final e in bank.exercises) {
        expect(_allowedTypes[skill]!.contains(e.type), isTrue, reason: e.id);
        expect(e.id, isNotEmpty);
        expect(e.answer, isNotEmpty);
      }
    }
  });

  test('SkillPracticeLoader pickSession respects limit', () {
    final loader = SkillPracticeLoader(random: Random(1));
    final exercises = [
      for (var i = 0; i < 20; i++)
        Exercise(
          id: 'e$i',
          type: ExerciseType.translateChoice,
          prompt: 'p$i',
          sentence: 's$i',
          options: const ['a', 'b'],
          answer: 'a',
        ),
    ];
    final picked = loader.pickSession(exercises, limit: 10);
    expect(picked.length, 10);
    expect(picked.map((e) => e.id).toSet().length, 10);
  });

  testWidgets('skill practice completes without updating course progress', (
    tester,
  ) async {
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('skill_practice'),
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

    final bankJson = File('assets/practice/vocabulary.json').readAsStringSync();
    final bank = SkillPracticeBank.fromJson(
      jsonDecode(bankJson) as Map<String, dynamic>,
    );
    final first = bank.exercises.firstWhere(
      (e) => e.type == ExerciseType.translateChoice,
    );

    final tinyBank = {
      'skill': 'vocabulary',
      'title': '单词练习',
      'exercises': [
        {
          'id': first.id,
          'type': first.type.name,
          'prompt': first.prompt,
          'sentence': first.sentence,
          'options': first.options,
          'answer': first.answer,
        },
      ],
    };

    final loader = SkillPracticeLoader(
      assetBundle: TestAssetBundle({
        SkillPracticeKind.vocabulary.assetPath: jsonEncode(tinyBank),
      }),
      random: Random(1),
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
                child: const Text('开始专项'),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SkillPracticePage(
                      skill: SkillPracticeKind.vocabulary,
                      loader: loader,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('开始专项'));
    await tester.pumpAndSettle();
    expect(find.textContaining('单词练习'), findsWidgets);

    // Choose correct option（选项现按词渲染音标文本，按 widget 内容查找）
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) => w is TappablePhoneticText && w.text == first.answer,
          )
          .first,
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('检查'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('单词练习完成'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('开始专项'), findsOneWidget);
    expect(Hive.box<LessonProgress>(ProgressStore.boxName).isEmpty, isTrue);
    expect(
      store.events.where((e) => e['mode'] == 'skill-vocabulary').isNotEmpty,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

/// 仅覆盖专项题库路径的测试 AssetBundle
class TestAssetBundle extends CachingAssetBundle {
  TestAssetBundle(this._strings);
  final Map<String, String> _strings;

  @override
  Future<ByteData> load(String key) async {
    throw FlutterError('Unexpected asset load: $key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = _strings[key];
    if (value == null) throw FlutterError('Missing test asset: $key');
    return value;
  }
}
