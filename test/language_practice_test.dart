import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/data/models/skill_practice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

import '../tool/generate_language_practice.dart';

/// 去掉声调/长短音等组合附加符号（NFD 后剔除）
String _stripMarks(String text) => unicode
    .nfd(text)
    .replaceAll(RegExp('[\\u0300\\u0301\\u0304\\u030C]'), '');

/// 天城体字符（用于确认选项里没有夹带原文）
final _devanagari = RegExp(r'[\u0900-\u097F]');

/// 汉字（用于区分中/英文选项）
final _hanzi = RegExp(r'[\u4e00-\u9fff]');

SkillPracticeBank _load(String path) => SkillPracticeBank.fromJson(
  jsonDecodeMap(File(path).readAsStringSync()),
);

Map<String, dynamic> jsonDecodeMap(String raw) =>
    (const JsonDecoder().convert(raw) as Map).cast<String, dynamic>();

void main() {
  group('专项练习语种归属', () {
    test('forLanguage 返回各语言的专项列表', () {
      expect(
        SkillPracticeKind.forLanguage(LearningLanguage.english),
        [
          SkillPracticeKind.pronunciation,
          SkillPracticeKind.vocabulary,
          SkillPracticeKind.speaking,
          SkillPracticeKind.englishYoga,
        ],
      );
      expect(
        SkillPracticeKind.forLanguage(LearningLanguage.chinese),
        [SkillPracticeKind.chineseTones, SkillPracticeKind.chineseCharacters],
      );
      expect(
        SkillPracticeKind.forLanguage(LearningLanguage.sanskrit),
        [
          SkillPracticeKind.sanskritLetters,
          SkillPracticeKind.sanskritVowels,
          SkillPracticeKind.sanskritYoga,
        ],
      );
    });
  });

  group('中文/梵文专项题库', () {
    final generated = generateLanguagePractice(write: false);

    test('生成结果与磁盘文件一致（需先运行生成器）', () {
      for (final entry in generated.entries) {
        final onDisk = File(entry.key);
        expect(onDisk.existsSync(), isTrue, reason: entry.key);
        expect(onDisk.readAsStringSync(), entry.value, reason: entry.key);
      }
    });

    test('六个题库可解析且题型安全', () {
      for (final path in generated.keys) {
        final bank = _load(path);
        expect(bank.exercises.length, greaterThanOrEqualTo(10), reason: path);
        for (final e in bank.exercises) {
          // 无音频安全：只出识读选择题
          expect(e.type, ExerciseType.translateChoice, reason: e.id);
          expect(e.options.length, 4, reason: e.id);
          expect(e.options.toSet().length, 4, reason: '${e.id} 选项重复');
          expect(e.options, contains(e.answer), reason: e.id);
        }
      }
    });

    test('题库语言标记正确（影响 NFC 判分）', () {
      for (final e in _load('assets/practice/chineseTones.json').exercises) {
        expect(e.language, LearningLanguage.chinese, reason: e.id);
      }
      for (final e
          in _load('assets/practice/chineseCharacters.json').exercises) {
        expect(e.language, LearningLanguage.chinese, reason: e.id);
      }
      for (final e in _load('assets/practice/sanskritLetters.json').exercises) {
        expect(e.language, LearningLanguage.sanskrit, reason: e.id);
      }
      for (final e in _load('assets/practice/sanskritVowels.json').exercises) {
        expect(e.language, LearningLanguage.sanskrit, reason: e.id);
      }
      for (final e in _load('assets/practice/sanskritYoga.json').exercises) {
        expect(e.language, LearningLanguage.sanskrit, reason: e.id);
      }
      for (final e in _load('assets/practice/englishYoga.json').exercises) {
        expect(e.language, LearningLanguage.english, reason: e.id);
      }
    });

    test('声调练习：选项是同一音节的四个声调变体', () {
      final bank = _load('assets/practice/chineseTones.json');
      for (final e in bank.exercises) {
        final bases = e.options.map(_stripMarks).toSet();
        expect(bases.length, 1, reason: '${e.id} 选项基音节不一致: $bases');
        // 四个声调齐全
        expect(
          e.options.map((o) => o).toSet().length,
          4,
          reason: e.id,
        );
      }
    });

    test('长短元音辨析：选项只在元音长短上不同', () {
      final bank = _load('assets/practice/sanskritVowels.json');
      for (final e in bank.exercises) {
        final bases = e.options.map(_stripMarks).toSet();
        expect(bases.length, 1, reason: '${e.id} 选项基串不一致: $bases');
      }
    });

    test('天城体辨认：答案均为课程已教字母或音节', () {
      const taught = {
        'a', 'ā', 'i', 'ī', 'u', 'ū', 'e', 'ai', 'o', 'au',
        'ka', 'ma', 'na', 'ta', 'ṭa',
        'kā', 'ki', 'kī', 'mā', 'mi', 'mī',
        'nā', 'ni', 'nī', 'tā', 'ti', 'tī',
        'ṭā', 'ṭi', 'ṭī',
      };
      final bank = _load('assets/practice/sanskritLetters.json');
      for (final e in bank.exercises) {
        expect(taught, contains(e.answer), reason: e.id);
      }
    });

    test('瑜伽梵文：识读与意义成对，术语不重复', () {
      final bank = _load('assets/practice/sanskritYoga.json');
      expect(bank.exercises.length, 40);
      final terms = <String>{};
      for (var i = 0; i < bank.exercises.length; i += 2) {
        final reading = bank.exercises[i];
        final meaning = bank.exercises[i + 1];
        // 识读题给出天城体，意义题用 IAST 提问；选项都不含天城体
        expect(reading.prompt, startsWith('选择 IAST：'), reason: reading.id);
        expect(meaning.prompt, contains(reading.answer), reason: meaning.id);
        for (final options in [reading.options, meaning.options]) {
          expect(options.any(_devanagari.hasMatch), isFalse);
        }
        expect(terms.add(reading.answer), isTrue, reason: reading.answer);
      }
      expect(terms.length, 20);
    });

    test('瑜伽英文：听音识义与译英成对，选项语言不混排', () {
      final bank = _load('assets/practice/englishYoga.json');
      expect(bank.exercises.length, 72);
      final englishAnswers = <String>{};
      for (var i = 0; i < bank.exercises.length; i += 2) {
        final listening = bank.exercises[i];
        final translating = bank.exercises[i + 1];
        // 听音识义：题干为英文，选项为中文
        expect(_hanzi.hasMatch(listening.prompt), isFalse, reason: listening.id);
        for (final option in listening.options) {
          expect(_hanzi.hasMatch(option), isTrue, reason: listening.id);
        }
        // 译英：题干为中文，选项为英文，且答案等于前一题朗读文本
        expect(translating.prompt, contains('用英语怎么说'), reason: translating.id);
        expect(_hanzi.hasMatch(translating.answer), isFalse, reason: translating.id);
        for (final option in translating.options) {
          expect(_hanzi.hasMatch(option), isFalse, reason: translating.id);
        }
        expect(translating.answer, listening.sentence, reason: translating.id);
        expect(translating.sentence, listening.sentence, reason: translating.id);
        expect(englishAnswers.add(listening.sentence), isTrue, reason: listening.id);
      }
      // 20 个术语 + 16 条指令
      expect(englishAnswers.length, 36);
    });
  });
}
