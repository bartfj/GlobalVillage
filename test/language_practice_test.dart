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
        ],
      );
      expect(
        SkillPracticeKind.forLanguage(LearningLanguage.chinese),
        [SkillPracticeKind.chineseTones, SkillPracticeKind.chineseCharacters],
      );
      expect(
        SkillPracticeKind.forLanguage(LearningLanguage.sanskrit),
        [SkillPracticeKind.sanskritLetters, SkillPracticeKind.sanskritVowels],
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

    test('四个题库可解析且题型安全', () {
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
  });
}
