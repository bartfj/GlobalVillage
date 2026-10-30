import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';

const _targetCount = 50;

const _skillTypes = <String, Set<ExerciseType>>{
  'pronunciation': {
    ExerciseType.listeningChoice,
    ExerciseType.listeningWordBank,
    ExerciseType.dictation,
    ExerciseType.speaking,
  },
  'vocabulary': {
    ExerciseType.matchPairs,
    ExerciseType.fillBlank,
    ExerciseType.translateChoice,
    ExerciseType.wordBank,
  },
  'speaking': {ExerciseType.speaking, ExerciseType.translateInput},
};

const _skillTitles = <String, String>{
  'pronunciation': '发音练习',
  'vocabulary': '单词练习',
  'speaking': '口语练习',
};

Map<String, dynamic> exerciseToJson(Exercise e) {
  return {
    'id': e.id,
    'type': e.type.name,
    'prompt': e.prompt,
    'sentence': e.sentence,
    'options': e.options,
    'answer': e.answer,
    if (e.acceptedAnswers.isNotEmpty) 'acceptedAnswers': e.acceptedAnswers,
    if (e.sentenceWithBlank != null) 'sentenceWithBlank': e.sentenceWithBlank,
    if (e.pairs.isNotEmpty)
      'pairs': [
        for (final p in e.pairs) {'left': p.left, 'right': p.right},
      ],
    if (e.audioId != null) 'audioId': e.audioId,
  };
}

String dedupeKey(Exercise e) {
  if (e.type == ExerciseType.matchPairs) {
    return '${e.type.name}|${e.answer}';
  }
  return '${e.type.name}|${e.sentence}|${e.answer}';
}

bool hasListeningAudio(Exercise e) =>
    File('assets/audio/listening/${e.id}.mp3').existsSync();

List<Exercise> _sampleByUnit(List<Exercise> pool, int limit, Set<String> seen) {
  if (pool.isEmpty || limit <= 0) return const [];

  final byUnit = <String, List<Exercise>>{};
  for (final e in pool) {
    final unit = e.id.split('l').first;
    byUnit.putIfAbsent(unit, () => []).add(e);
  }

  final unitIds = byUnit.keys.toList()..sort();
  final result = <Exercise>[];
  var round = 0;

  while (result.length < limit) {
    var added = false;
    for (final unitId in unitIds) {
      final list = byUnit[unitId]!;
      if (round >= list.length) continue;
      final e = list[round];
      final key = dedupeKey(e);
      if (seen.add(key)) {
        result.add(e);
        added = true;
        if (result.length >= limit) break;
      }
    }
    if (!added) break;
    round++;
  }

  return result;
}

/// 优先抽有内置音频的题，不足再补无音频题；两段均按单元均匀。
List<Exercise> sampleEvenly(List<Exercise> pool, int limit) {
  if (pool.length <= limit) return List.of(pool);

  final withAudio = pool.where(hasListeningAudio).toList();
  final withoutAudio = pool.where((e) => !hasListeningAudio(e)).toList();
  final seen = <String>{};
  final result = <Exercise>[..._sampleByUnit(withAudio, limit, seen)];
  if (result.length < limit) {
    result.addAll(_sampleByUnit(withoutAudio, limit - result.length, seen));
  }
  return result;
}

void main() {
  final pools = <String, List<Exercise>>{
    for (final skill in _skillTypes.keys) skill: <Exercise>[],
  };
  final seen = <String, Set<String>>{
    for (final skill in _skillTypes.keys) skill: <String>{},
  };

  for (final track in ['zero', 'beginner', 'intermediate']) {
    final course = Course.fromJson(
      jsonDecode(File('assets/courses/course_$track.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    for (final unit in course.units) {
      for (final lesson in unit.lessons) {
        for (final exercise in lesson.exercises) {
          for (final entry in _skillTypes.entries) {
            if (!entry.value.contains(exercise.type)) continue;
            final key = dedupeKey(exercise);
            if (!seen[entry.key]!.add(key)) continue;
            pools[entry.key]!.add(exercise);
          }
        }
      }
    }
  }

  final outDir = Directory('assets/practice')..createSync(recursive: true);
  for (final skill in _skillTypes.keys) {
    final sampled = sampleEvenly(pools[skill]!, _targetCount);
    final chapters = _chaptersForClassicSkill(skill, sampled);
    final payload = {
      'skill': skill,
      'title': _skillTitles[skill],
      'chapters': chapters,
    };
    final file = File('${outDir.path}/$skill.json');
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload) + '\n',
    );
    final total = chapters.fold<int>(
      0,
      (n, c) => n + (c['exercises'] as List).length,
    );
    stdout.writeln(
      '$skill: pool=${pools[skill]!.length} selected=$total chapters=${chapters.length} → ${file.path}',
    );
  }
}

int _unitSortKey(String unit) {
  if (unit.startsWith('i_u')) {
    return 1000 + (int.tryParse(unit.substring(3)) ?? 0);
  }
  if (unit.startsWith('u')) {
    return int.tryParse(unit.substring(1)) ?? 0;
  }
  return 9999;
}

String _unitOf(Exercise e) => e.id.split('l').first;

/// 经典英语三项：按单元排序后均分为 5 章（主题带命名）
List<Map<String, dynamic>> _chaptersForClassicSkill(
  String skill,
  List<Exercise> sampled,
) {
  final sorted = List<Exercise>.of(sampled)
    ..sort((a, b) => _unitSortKey(_unitOf(a)).compareTo(_unitSortKey(_unitOf(b))));

  const meta = <String, List<(String, String, String)>>{
    'pronunciation': [
      ('pr-early', '入门听辨', '问候到爱好'),
      ('pr-daily', '日常听辨', '社交到自然'),
      ('pr-life', '生活听辨', '科技到综合'),
      ('pr-adult', '场景听辨', '职场到求助'),
      ('pr-services', '事务听辨', '环保到旅行'),
    ],
    'vocabulary': [
      ('voc-basics', '基础词义', '问候到运动'),
      ('voc-plans', '计划与生活', '计划到社区'),
      ('voc-adult', '成人主题', '理财到数字生活'),
      ('voc-inter-a', '中级协作', '叙述到投诉'),
      ('voc-inter-b', '中级思辨', '新闻到综合'),
    ],
    'speaking': [
      ('spk-early', '入门跟读', '问候到爱好'),
      ('spk-daily', '日常跟读', '社交到自然'),
      ('spk-life', '生活跟读', '科技到综合'),
      ('spk-adult', '场景跟读', '职场到求助'),
      ('spk-services', '事务跟读', '环保到旅行'),
    ],
  };

  final labels = meta[skill]!;
  final chapterCount = labels.length;
  final chapters = <Map<String, dynamic>>[];
  for (var i = 0; i < chapterCount; i++) {
    final start = (sorted.length * i / chapterCount).floor();
    final end = (sorted.length * (i + 1) / chapterCount).floor();
    final slice = sorted.sublist(start, end);
    final (id, title, subtitle) = labels[i];
    chapters.add({
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'exercises': [for (final e in slice) exerciseToJson(e)],
    });
  }
  return chapters;
}
