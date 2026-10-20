import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/data/models/skill_practice.dart';

import 'generate_skill_practice.dart' show exerciseToJson;

/// 与 exerciseToJson 相同，但额外输出 language（影响 NFC 判分归一化）。
Map<String, dynamic> _exerciseJson(Exercise e) => {
  ...exerciseToJson(e),
  'language': e.language.name,
};

/// 中文/梵文专项练习题库生成器。
///
/// 内容原则（设计文档 12.2/12.3/12.4）：
/// - 无音频安全题型：只产出 translateChoice（识读/意义选择）；
/// - 中文声调练习：选项为同一音节的四个声调变体（最小对立对）；
/// - 中文汉字识读：双向（字→义、义→字），干扰项取同批已学词；
/// - 梵文天城体辨认：只考课程已教字母与音节；
/// - 梵文长短元音：选项只在元音长短上不同，字母均来自已教集合。

// ---------------------------------------------------------------------------
// 中文声调练习
// ---------------------------------------------------------------------------

const _toneForms = <String, List<String>>{
  'a': ['a', 'ā', 'á', 'ǎ', 'à'],
  'e': ['e', 'ē', 'é', 'ě', 'è'],
  'i': ['i', 'ī', 'í', 'ǐ', 'ì'],
  'o': ['o', 'ō', 'ó', 'ǒ', 'ò'],
  'u': ['u', 'ū', 'ú', 'ǔ', 'ù'],
  'ü': ['ü', 'ǖ', 'ǘ', 'ǚ', 'ǜ'],
};

/// 找出读音中的标调元音，返回四个声调变体（一声到四声）。
List<String> toneVariants(String reading) {
  for (var i = 0; i < reading.length; i++) {
    for (final entry in _toneForms.entries) {
      final forms = entry.value;
      if (forms.contains(reading[i]) && reading[i] != entry.key) {
        return [
          for (var t = 1; t <= 4; t++)
            reading.replaceRange(i, i + 1, forms[t]),
        ];
      }
    }
  }
  throw ArgumentError('未找到标调元音: $reading');
}

/// （汉字, 读音, 词义）——均来自中文课程已学语料。
const _toneItems = <(String, String, String)>[
  ('妈', 'mā', 'mother'),
  ('麻', 'má', 'hemp'),
  ('马', 'mǎ', 'horse'),
  ('骂', 'mà', 'to scold'),
  ('你', 'nǐ', 'you'),
  ('好', 'hǎo', 'good'),
  ('我', 'wǒ', 'I; me'),
  ('他', 'tā', 'he'),
  ('是', 'shì', 'to be'),
  ('叫', 'jiào', 'to be called'),
  ('老', 'lǎo', 'old'),
  ('学', 'xué', 'to study'),
  ('一', 'yī', 'one'),
  ('二', 'èr', 'two'),
  ('三', 'sān', 'three'),
  ('四', 'sì', 'four'),
  ('五', 'wǔ', 'five'),
  ('个', 'gè', '(measure word)'),
  ('人', 'rén', 'person'),
  ('书', 'shū', 'book'),
  ('茶', 'chá', 'tea'),
  ('喝', 'hē', 'to drink'),
  ('想', 'xiǎng', 'to want; to think'),
  ('要', 'yào', 'to want; to order'),
  ('米', 'mǐ', 'rice'),
  ('饭', 'fàn', 'meal; cooked rice'),
  ('吃', 'chī', 'to eat'),
];

List<Exercise> _buildChineseTones() {
  return [
    for (var i = 0; i < _toneItems.length; i++)
      () {
        final (hanzi, reading, gloss) = _toneItems[i];
        final variants = toneVariants(reading);
        // 轮换答案位置，避免答案总在同一处
        final shift = i % 4;
        final options = [
          ...variants.sublist(shift),
          ...variants.sublist(0, shift),
        ];
        return Exercise(
          id: 'zht${(i + 1).toString().padLeft(2, '0')}',
          type: ExerciseType.translateChoice,
          prompt: 'Choose the correct pinyin for $hanzi ($gloss)',
          sentence: reading,
          options: options,
          answer: reading,
          language: LearningLanguage.chinese,
        );
      }(),
  ];
}

// ---------------------------------------------------------------------------
// 中文汉字识读
// ---------------------------------------------------------------------------

/// （汉字词, 拼音, 词义）——均来自中文课程已学语料，词义互不相同。
const _charWords = <(String, String, String)>[
  ('妈', 'mā', 'mother'),
  ('好', 'hǎo', 'good'),
  ('谢谢', 'xièxie', 'thanks'),
  ('再见', 'zàijiàn', 'goodbye'),
  ('我', 'wǒ', 'I; me'),
  ('叫', 'jiào', 'to be called'),
  ('老师', 'lǎoshī', 'teacher'),
  ('学生', 'xuésheng', 'student'),
  ('是', 'shì', 'to be'),
  ('他', 'tā', 'he'),
  ('一', 'yī', 'one'),
  ('二', 'èr', 'two'),
  ('三', 'sān', 'three'),
  ('四', 'sì', 'four'),
  ('五', 'wǔ', 'five'),
  ('人', 'rén', 'person'),
  ('书', 'shū', 'book'),
  ('茶', 'chá', 'tea'),
  ('咖啡', 'kāfēi', 'coffee'),
  ('喝', 'hē', 'to drink'),
  ('想', 'xiǎng', 'to want; to think'),
  ('要', 'yào', 'to want; to order'),
  ('米饭', 'mǐfàn', 'cooked rice'),
  ('面条', 'miàntiáo', 'noodles'),
  ('吃', 'chī', 'to eat'),
];

List<Exercise> _buildChineseCharacters() {
  final exercises = <Exercise>[];
  final n = _charWords.length;
  for (var i = 0; i < n; i++) {
    final (hanzi, pinyin, gloss) = _charWords[i];
    // 字 → 义
    final glossOptions = [gloss, _charWords[(i + 1) % n].$3,
        _charWords[(i + 2) % n].$3, _charWords[(i + 3) % n].$3];
    final gShift = i % 4;
    exercises.add(
      Exercise(
        id: 'zhc${(exercises.length + 1).toString().padLeft(2, '0')}',
        type: ExerciseType.translateChoice,
        prompt: 'What does $hanzi mean?',
        sentence: gloss,
        options: [
          ...glossOptions.sublist(gShift),
          ...glossOptions.sublist(0, gShift),
        ],
        answer: gloss,
        language: LearningLanguage.chinese,
      ),
    );
    // 义 → 字
    final hanziOptions = [hanzi, _charWords[(i + 1) % n].$1,
        _charWords[(i + 2) % n].$1, _charWords[(i + 3) % n].$1];
    final hShift = (i + 1) % 4;
    exercises.add(
      Exercise(
        id: 'zhc${(exercises.length + 1).toString().padLeft(2, '0')}',
        type: ExerciseType.translateChoice,
        prompt: 'Select the characters: $gloss',
        sentence: hanzi,
        options: [
          ...hanziOptions.sublist(hShift),
          ...hanziOptions.sublist(0, hShift),
        ],
        answer: hanzi,
        language: LearningLanguage.chinese,
      ),
    );
  }
  return exercises;
}

// ---------------------------------------------------------------------------
// 梵文天城体辨认（只考课程已教字母与音节）
// ---------------------------------------------------------------------------

const _saVowelSigns = <(String, String)>[
  ('अ', 'a'), ('आ', 'ā'), ('इ', 'i'), ('ई', 'ī'), ('उ', 'u'),
  ('ऊ', 'ū'), ('ए', 'e'), ('ऐ', 'ai'), ('ओ', 'o'), ('औ', 'au'),
];

const _saConsonants = <(String, String)>[
  ('क', 'ka'), ('म', 'ma'), ('न', 'na'), ('त', 'ta'), ('ट', 'ṭa'),
];

const _saSyllables = <(String, String)>[
  ('का', 'kā'), ('कि', 'ki'), ('की', 'kī'),
  ('मा', 'mā'), ('मि', 'mi'), ('मी', 'mī'),
  ('ना', 'nā'), ('नि', 'ni'), ('नी', 'nī'),
  ('ता', 'tā'), ('ति', 'ti'), ('ती', 'tī'),
  ('टा', 'ṭā'), ('टि', 'ṭi'), ('टी', 'ṭī'),
];

List<Exercise> _saLetterExercises(
  String idPrefix,
  int startIndex,
  List<(String, String)> items,
) {
  final n = items.length;
  return [
    for (var i = 0; i < n; i++)
      () {
        final (sign, iast) = items[i];
        final distractors = [
          items[(i + 1) % n].$2,
          items[(i + 2) % n].$2,
          items[(i + 3) % n].$2,
        ];
        final insertAt = i % 4;
        final options = [...distractors]..insert(insertAt, iast);
        return Exercise(
          id: '$idPrefix${(startIndex + i).toString().padLeft(2, '0')}',
          type: ExerciseType.translateChoice,
          prompt: '选择 IAST：$sign',
          sentence: iast,
          options: options,
          answer: iast,
          language: LearningLanguage.sanskrit,
        );
      }(),
  ];
}

List<Exercise> _buildSanskritLetters() {
  return [
    ..._saLetterExercises('sal', 1, _saVowelSigns),
    ..._saLetterExercises('sal', _saVowelSigns.length + 1, _saConsonants),
    ..._saLetterExercises(
      'sal',
      _saVowelSigns.length + _saConsonants.length + 1,
      _saSyllables,
    ),
  ];
}

// ---------------------------------------------------------------------------
// 梵文长短元音辨析（选项只在元音长短上不同）
// ---------------------------------------------------------------------------

/// 课程已学词与由已教字母组成的字符串（天城体, IAST）。
const _saLengthItems = <(String, String)>[
  ('मम', 'mama'),
  ('नाम', 'nāma'),
  ('आम', 'āma'),
  ('काक', 'kāka'),
  ('नट', 'naṭa'),
  ('मट', 'maṭa'),
  ('मत', 'mata'),
  ('नत', 'nata'),
  ('तत', 'tata'),
  ('टट', 'ṭaṭa'),
  ('मित', 'mita'),
  ('कित', 'kita'),
  ('नीत', 'nīta'),
  ('तीन', 'tīna'),
  ('मीन', 'mīna'),
  ('कीन', 'kīna'),
];

const _saFlip = {
  'a': 'ā', 'ā': 'a',
  'i': 'ī', 'ī': 'i',
  'u': 'ū', 'ū': 'u',
};

/// 找出 IAST 中的元音位置，生成 4 个长短组合（原式 + 三种翻转）。
List<String> lengthVariants(String iast) {
  final positions = <int>[];
  for (var i = 0; i < iast.length; i++) {
    if (_saFlip.containsKey(iast[i])) positions.add(i);
  }
  if (positions.length != 2) {
    throw ArgumentError('需要恰好两个元音: $iast');
  }
  String flipAt(String s, int pos) =>
      s.replaceRange(pos, pos + 1, _saFlip[s[pos]]!);
  final variants = {
    iast,
    flipAt(iast, positions[0]),
    flipAt(iast, positions[1]),
    flipAt(flipAt(iast, positions[0]), positions[1]),
  }.toList();
  if (variants.length != 4) {
    throw ArgumentError('长短变体不唯一: $iast');
  }
  return variants;
}

List<Exercise> _buildSanskritVowels() {
  return [
    for (var i = 0; i < _saLengthItems.length; i++)
      () {
        final (sign, iast) = _saLengthItems[i];
        final variants = lengthVariants(iast);
        final others = variants.where((v) => v != iast).toList();
        final insertAt = i % 4;
        final options = [...others]..insert(insertAt, iast);
        return Exercise(
          id: 'sav${(i + 1).toString().padLeft(2, '0')}',
          type: ExerciseType.translateChoice,
          prompt: '选择正确的 IAST：$sign',
          sentence: iast,
          options: options,
          answer: iast,
          language: LearningLanguage.sanskrit,
        );
      }(),
  ];
}

// ---------------------------------------------------------------------------
// 输出
// ---------------------------------------------------------------------------

/// 生成 4 个题库，返回 {路径: 内容}；write 为 true 时同时写盘。
Map<String, String> generateLanguagePractice({bool write = true}) {
  final banks = <SkillPracticeKind, List<Exercise>>{
    SkillPracticeKind.chineseTones: _buildChineseTones(),
    SkillPracticeKind.chineseCharacters: _buildChineseCharacters(),
    SkillPracticeKind.sanskritLetters: _buildSanskritLetters(),
    SkillPracticeKind.sanskritVowels: _buildSanskritVowels(),
  };
  final out = <String, String>{};
  for (final entry in banks.entries) {
    final payload = {
      'skill': entry.key.name,
      'title': entry.key.title,
      'exercises': [for (final e in entry.value) _exerciseJson(e)],
    };
    final content =
        '${const JsonEncoder.withIndent('  ').convert(payload)}\n';
    final path = 'assets/practice/${entry.key.name}.json';
    if (write) {
      File(path).writeAsStringSync(content);
    }
    out[path] = content;
  }
  return out;
}

void main() {
  final out = generateLanguagePractice();
  for (final entry in out.entries) {
    final count = RegExp(r'"id"').allMatches(entry.value).length;
    stdout.writeln('${entry.key}: $count 题');
  }
}
