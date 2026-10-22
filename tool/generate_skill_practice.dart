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
    final payload = {
      'skill': skill,
      'title': _skillTitles[skill],
      'exercises': [for (final e in sampled) exerciseToJson(e)],
    };
    final file = File('${outDir.path}/$skill.json');
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload) + '\n',
    );
    stdout.writeln(
      '$skill: pool=${pools[skill]!.length} selected=${sampled.length} → ${file.path}',
    );
  }
}
