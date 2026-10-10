import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';

import 'expand_course_content.dart' show buildExercises;
import 'expansion_material.dart';

const expansionBases = {'zero': 42, 'beginner': 52, 'intermediate': 0};
const expansionPrefixes = {
  'zero': 'z_u',
  'beginner': 'u',
  'intermediate': 'i_u',
};
const lessonSelections = [
  [0, 1, 2, 3],
  [4, 5, 6, 7],
  [0, 2, 4, 6],
  [1, 3, 5, 7],
];

List<String> translationAlternatives(String sentence) {
  final answers = <String>[];
  for (final entry in const {
    'I will ': "I'll ",
    'I am ': "I'm ",
    'I would like ': "I'd like ",
    'It is ': "It's ",
    'She is ': "She's ",
  }.entries) {
    if (sentence.startsWith(entry.key)) {
      answers.add(sentence.replaceFirst(entry.key, entry.value));
    }
  }
  return answers;
}

void main() => generateExpansion();

Map<String, String> generateExpansion({bool write = true}) {
  const encoder = JsonEncoder.withIndent('  ');
  final dialogueFile = File('assets/dialogues/unit_dialogues.json');
  final taskFile = File('assets/dialogues/application_tasks.json');
  final dialogues =
      jsonDecode(dialogueFile.readAsStringSync()) as Map<String, dynamic>;
  final tasks = jsonDecode(taskFile.readAsStringSync()) as Map<String, dynamic>;
  final output = <String, String>{};
  final ledger = StringBuffer(
    '# 新增192课教学台账\n\n'
    '零基础43–58单元、初级53–68单元、中级1–16单元。每单元8条人工编写的核心表达，'
    '按4条新授、4条应用、交错复现、综合表达组织4课，每课9题。'
    '复现并非额外新授词汇。中级以B1能力为设计目标，不提供等级认证。\n\n'
    '新授候选按英文词形统计；先修来源仅说明内容出现位置，不增加解锁门槛。'
    '人工教学审校、逐句录音和真实设备TTS验收尚待完成。\n\n',
  );
  final directory = StringBuffer('# 本轮扩课目录\n\n');
  var totalLessons = 0;
  for (final entry in expansionMaterial.entries) {
    final track = entry.key;
    final base = expansionBases[track]!;
    final prefix = expansionPrefixes[track]!;
    final path = 'assets/courses/course_$track.json';
    final file = File(path);
    final course = file.existsSync()
        ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
        : <String, dynamic>{'id': track, 'title': '英语中级', 'units': <dynamic>[]};
    final units = course['units'] as List;
    if (course['id'] != track ||
        (units.length != base && units.length != base + 16)) {
      throw StateError('Unexpected course or unit count: $track');
    }
    final seen = <String, String>{};
    void remember(String sentence, String lessonId) {
      for (final match in RegExp(
        r"[A-Za-z]+(?:'[A-Za-z]+)?",
      ).allMatches(sentence)) {
        seen.putIfAbsent(match.group(0)!.toLowerCase(), () => lessonId);
      }
    }

    for (final unit in units.take(base)) {
      for (final lesson in unit['lessons']) {
        for (final ex in lesson['exercises']) {
          remember(ex['sentence'] as String, lesson['id'] as String);
        }
      }
    }
    units.removeRange(base, units.length);
    final blocks = entry.value.trim().split(RegExp(r'\n\s*\n'));
    if (blocks.length != 16) throw StateError('Expected 16 units for $track');
    directory.writeln(
      '## ${course['title']}\n\n| 单元 | 主题 | 四课顺序 |\n|---|---|---|',
    );
    for (var u = 0; u < blocks.length; u++) {
      final lines = blocks[u].split('\n').map((s) => s.trim()).toList();
      final headings = lines.first.split('|');
      if (lines.length != 9 || headings.length != 5) {
        throw FormatException(
          'Expected title, four lessons, eight pairs: ${lines.first}',
        );
      }
      final material = lines.skip(1).map((line) => line.split('~')).toList();
      if (material.any(
            (p) => p.length != 3 || p.any((s) => s.trim().isEmpty),
          ) ||
          material.map((p) => p[0]).toSet().length != 8 ||
          material.map((p) => p[1]).toSet().length != 8) {
        throw FormatException(
          'Invalid or duplicate expressions: ${headings.first}',
        );
      }
      for (final pair in material) {
        if (!RegExp('\\b${RegExp.escape(pair[2])}\\b').hasMatch(pair[0])) {
          throw FormatException(
            'Blank target missing: ${pair[0]} / ${pair[2]}',
          );
        }
      }
      final unitId = '$prefix${base + u + 1}';
      final lessons = <Map<String, dynamic>>[];
      for (var l = 0; l < 4; l++) {
        final lessonId = '${unitId}l${l + 1}';
        final selected = [for (final i in lessonSelections[l]) material[i]];
        final pairs = [
          for (final p in selected) MatchPair(left: p[1], right: p[0]),
        ];
        final exercises = buildExercises(lessonId, pairs, l);
        final target = selected[3][2];
        exercises[7]['answer'] = target;
        exercises[7]['sentenceWithBlank'] = selected[3][0].replaceFirst(
          RegExp('\\b${RegExp.escape(target)}\\b'),
          '____',
        );
        for (final ex in exercises) {
          if (ex['type'] == 'translateInput') {
            ex['acceptedAnswers'] = translationAlternatives(
              ex['answer'] as String,
            );
          }
        }
        lessons.add({
          'id': lessonId,
          'title': headings[l + 1],
          'exercises': exercises,
        });
        final words = selected
            .expand(
              (p) => RegExp(
                r"[A-Za-z]+(?:'[A-Za-z]+)?",
              ).allMatches(p[0]).map((m) => m.group(0)!.toLowerCase()),
            )
            .toSet();
        final newWords = words.where((w) => !seen.containsKey(w)).toList()
          ..sort();
        final reused = words.where(seen.containsKey).toList()..sort();
        ledger.writeln(
          '## $lessonId ${headings[0]} · ${headings[l + 1]}\n\n'
          '- 场景目标：${headings[0]}中的${headings[l + 1]}。\n'
          '- 阶段：${['基础表达', '场景应用', '交错复现', '综合表达'][l]}。\n'
          '- 新授候选词形：${newWords.join(', ')}。\n'
          '- 复现词形：${reused.join(', ')}。\n'
          '- 先修来源：${reused.map((w) => seen[w]).toSet().join(', ')}。\n'
          '- 核心表达：${selected.map((p) => p[0]).join(' / ')}\n'
          '- 输出目标：${exercises[4]['answer']}\n'
          '- 听力目标：${exercises[6]['sentence']}\n'
          '- 填空目标：$target。\n'
          '- 技能：理解、组句、听写或听音组句、翻译、跟读。\n'
          '- 难度说明：${track == 'intermediate'
              ? '包含连接、解释、条件与委婉表达，需初级基础；不是开放写作或等级测评'
              : track == 'zero'
              ? '短句场景训练，末单元有受控过去经历表达'
              : '日常事务交流，含过去经历、礼貌请求与简单条件表达'}。\n',
        );
        for (final p in selected) {
          remember(p[0], lessonId);
        }
        totalLessons++;
      }
      units.add({
        'id': unitId,
        'title': headings[0],
        'description': '在${headings[0]}场景中学习、复现并运用常用表达。',
        'lessons': lessons,
      });
      dialogues[unitId] = [
        for (var i = 0; i < 3; i++)
          {
            'speaker': i % 2,
            'english': material[i][0],
            'chinese': material[i][1],
          },
      ];
      final options = [
        material[1][1],
        material[3][1],
        material[5][1],
        material[7][1],
      ];
      final rotation = u % 4;
      tasks[unitId] = {
        'question': '根据对话，对方怎样回应第一个问题？',
        'options': [...options.skip(rotation), ...options.take(rotation)],
        'answer': material[1][1],
        'scenario': '在“${headings[0]}”场景中表达：${material[7][1]}',
        'sentence': material[7][0],
      };
      directory.writeln(
        '| ${base + u + 1} | ${headings[0]} | ${headings.skip(1).join('；')} |',
      );
    }
    output[path] = '${encoder.convert(course)}\n';
    directory.writeln();
    stdout.writeln(
      '$track: ${units.length} units, ${units.length * 4} lessons',
    );
  }
  if (totalLessons != 192) throw StateError('Expected 192 new lessons');
  output[dialogueFile.path] = '${encoder.convert(dialogues)}\n';
  output[taskFile.path] = '${encoder.convert(tasks)}\n';
  output['docs/新增192课教学台账.md'] = '${ledger.toString().trimRight()}\n';
  output['docs/本轮扩课目录.md'] = '${directory.toString().trimRight()}\n';
  // Validate every authored block before updating any generated resource.
  if (write) {
    for (final entry in output.entries) {
      File(entry.key).writeAsStringSync(entry.value);
    }
  }
  return output;
}
