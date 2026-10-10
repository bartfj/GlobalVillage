import 'dart:convert';
import 'dart:io';

const blankTargets = {
  'zero':
      '''grass closed basket boots strong small flowers garden cups blanket outside clean
name address open reply museum first low clock first here help away soon window clear here
together on friend dinner''',
  'beginner':
      '''seat scanner announcement bag fee receipt tomorrow replacement inspect Friday price
guaranteed form fairly together again date alone points out total emergencies costs now week answer
suggestions difference city interesting early again''',
};

const alternatives = {
  'I would like to open an account.': ['I want to open an account.'],
  'I need to withdraw some cash.': ['I need to take out some cash.'],
  'I would like to transfer money.': ['I want to transfer money.'],
  'My bank card is missing.': ['I cannot find my bank card.'],
  'I would like to volunteer here.': ['I want to volunteer here.'],
  'I would like to join the evening class.': [
    'I want to join the evening class.',
  ],
};

const distractors = {
  'z_u35l1e1': ['This is a park.', 'This is a school.', 'This is a garden.'],
  'z_u36l1e1': [
    'This flower is red.',
    'This flower is white.',
    'This flower is yellow.',
  ],
  'z_u37l1e1': [
    'We need some apples.',
    'We need some water.',
    'We need some cups.',
  ],
  'z_u38l1e1': [
    'I read a short letter.',
    'I write a short story.',
    'I read a short story.',
  ],
  'u46l1e1': [
    'I would like to close an account.',
    'I would like to withdraw some cash.',
    'I would like to transfer money.',
  ],
};

void main() {
  final encoder = const JsonEncoder.withIndent('  ');
  final ledger = StringBuffer(
    '# 新增64课教学台账\n\n'
    '自动提取的词汇台账与人工指定填空目标。语料保持不变以兼容既有录音。'
    '词汇仅按词形统计，不代表词元或已掌握水平。先修来源是内容出现位置，不是新增解锁条件。\n\n',
  );
  final revision = StringBuffer(
    '# 内容审校与修订记录\n\n'
    '范围：零基础35–42单元、初级45–52单元。课程ID、完整句子和音频不变。\n\n'
    '## 难度处理\n\n'
    '零基础后段的过去时、被动和从句保留为扩展表达，标记为需要先修讲解；'
    '不宣称已经完成全部人工教学审校。初级保留事务性表达。\n\n'
    '## 单答案歧义\n\n'
    '输入翻译允许显式维护等价答案及部分已知缩写；听写、选择、连线不放宽。'
    '没有收录的自然译法仍可能被拒绝，后续按试学反馈追加，不使用模糊相似度判写作。\n\n'
    '## 题目修订\n\n',
  );
  for (final track in ['zero', 'beginner']) {
    final file = File('assets/courses/course_$track.json');
    final course = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final base = track == 'zero' ? 34 : 44;
    final targets = blankTargets[track]!.split(RegExp(r'\s+'));
    if (targets.length != 32) throw StateError('Expected 32 blank targets');
    final seen = <String, String>{};
    var index = 0;
    for (var u = 0; u < (course['units'] as List).length; u++) {
      final unit = course['units'][u];
      for (final lesson in unit['lessons']) {
        final exercises = lesson['exercises'] as List;
        final pairs = exercises[2]['pairs'] as List;
        final sentences = pairs.map((p) => p['right'] as String).toList();
        final words = sentences
            .expand(
              (s) => RegExp(
                r"[A-Za-z]+(?:'[A-Za-z]+)?",
              ).allMatches(s).map((m) => m.group(0)!.toLowerCase()),
            )
            .toSet();
        if (u >= base) {
          final ex = exercises[7];
          final target = targets[index++];
          final sentence = ex['sentence'] as String;
          final pattern = RegExp('\\b${RegExp.escape(target)}\\b');
          if (!pattern.hasMatch(sentence)) {
            throw StateError('${lesson['id']}: $target');
          }
          ex['answer'] = target;
          ex['sentenceWithBlank'] = sentence.replaceFirst(pattern, '____');
          revision.writeln('- `${ex['id']}`：填空目标改为 `$target`。');
          for (final e in exercises) {
            if (e['type'] == 'translateInput') {
              final answer = e['answer'] as String;
              final accepted = <String>{...alternatives[answer] ?? []};
              for (final entry in const {
                'I would like': "I'd like",
                'I am ': "I'm ",
                'I will ': "I'll ",
                'We do not ': "We don't ",
                'I cannot ': "I can't ",
              }.entries) {
                if (answer.startsWith(entry.key)) {
                  accepted.add(answer.replaceFirst(entry.key, entry.value));
                }
              }
              e['acceptedAnswers'] = accepted.toList();
              if (accepted.isNotEmpty) {
                revision.writeln('- `${e['id']}`：等价答案 ${accepted.join(' / ')}');
              }
            }
            final choices = distractors[e['id']];
            if (choices != null) {
              final all = [e['answer'], ...choices];
              final rotation = index % 4;
              e['options'] = [...all.skip(rotation), ...all.take(rotation)];
              revision.writeln('- `${e['id']}`：改用场景内干扰项，区分动作、地点或属性。');
            }
          }
          final newWords = words.where((w) => !seen.containsKey(w)).toList()
            ..sort();
          final oldWords = words.where(seen.containsKey).toList()..sort();
          final sources = oldWords.map((w) => seen[w]!).toSet().toList();
          final complex = sentences.any(
            (s) => RegExp(
              r'\b(did|was|were|until|allowed|saw)\b',
              caseSensitive: false,
            ).hasMatch(s),
          );
          ledger.writeln(
            '## ${lesson['id']} ${unit['title']} · ${lesson['title']}\n\n'
            '- 场景目标：在“${unit['title']}”中完成“${lesson['title']}”相关表达。\n'
            '- 新授候选词形：${newWords.join(', ')}。\n'
            '- 复现词形：${oldWords.join(', ')}。\n'
            '- 先修来源：${sources.join(', ')}。\n'
            '- 核心表达：${sentences.join(' / ')}\n'
            '- 输出目标：${exercises[4]['answer']}\n'
            '- 听力目标：${exercises[6]['sentence']}\n'
            '- 填空目标：$target。\n'
            '- 技能：词义理解、词序、听音理解、受控输出、跟读。\n'
            '- 难度提示：${complex ? '存在过去时、被动或连接表达，需先修讲解与人工复核' : '按场景短句训练，仍需人工核对生词负荷'}。\n',
          );
        }
        for (final word in words) {
          seen.putIfAbsent(word, () => lesson['id'] as String);
        }
      }
    }
    file.writeAsStringSync('${encoder.convert(course)}\n');
  }
  File('docs/新增64课教学台账.md').writeAsStringSync(ledger.toString());
  File('docs/内容审校与修订记录.md').writeAsStringSync(revision.toString());
}
