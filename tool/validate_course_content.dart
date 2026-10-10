import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final ids = <String>{};
  final dialogues =
      jsonDecode(
            File('assets/dialogues/unit_dialogues.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final track in ['zero', 'beginner']) {
    final course = Course.fromJson(
      jsonDecode(File('assets/courses/course_$track.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final count = track == 'zero' ? 42 : 52;
    final prefix = track == 'zero' ? 'z_u' : 'u';
    require(course.units.length == count, '$track unit count');
    for (var u = 0; u < count; u++) {
      final unit = course.units[u];
      require(unit.id == '$prefix${u + 1}', 'Unit order: ${unit.id}');
      require(unit.lessons.length == 4, 'Lesson count: ${unit.id}');
      final lines = dialogues[unit.id] as List?;
      require(lines != null && lines.length == 3, 'Dialogue: ${unit.id}');
      for (final line in lines!) {
        require(line['speaker'] == 0 || line['speaker'] == 1, 'Speaker');
        require(
          (line['english'] as String).trim().isNotEmpty &&
              (line['chinese'] as String).trim().isNotEmpty,
          'Dialogue text',
        );
      }
      for (var l = 0; l < 4; l++) {
        final lesson = unit.lessons[l];
        require(lesson.id == '${unit.id}l${l + 1}', 'Lesson order');
        require(lesson.exercises.length == 9, 'Exercise count: ${lesson.id}');
        for (var e = 0; e < 9; e++) {
          final ex = lesson.exercises[e];
          require(
            ex.id == '${lesson.id}e${e + 1}' && ids.add(ex.id),
            'ID: ${ex.id}',
          );
          require(ex.answer.isNotEmpty, 'Answer: ${ex.id}');
          require(
            ex.acceptedAnswers.isEmpty ||
                ex.type == ExerciseType.translateInput,
            'Alternatives only for translation input: ${ex.id}',
          );
          require(
            ex.acceptedAnswers.every((a) => a.trim().isNotEmpty),
            'Empty alternative: ${ex.id}',
          );
          require(
            ex.acceptedAnswers.map(Exercise.normalizeAnswer).toSet().length ==
                ex.acceptedAnswers.length,
            'Duplicate alternatives: ${ex.id}',
          );
          switch (ex.type) {
            case ExerciseType.translateChoice:
            case ExerciseType.listeningChoice:
              require(
                ex.options.length == 4 &&
                    ex.options.toSet().length == 4 &&
                    ex.options.contains(ex.answer),
                'Choices: ${ex.id}',
              );
            case ExerciseType.fillBlank:
              require(
                ex.sentenceWithBlank?.replaceFirst('____', ex.answer) ==
                    ex.sentence,
                'Blank: ${ex.id}',
              );
            case ExerciseType.matchPairs:
              require(
                ex.pairs.length == 4 &&
                    ex.pairs.map((p) => p.left).toSet().length == 4 &&
                    ex.pairs.map((p) => p.right).toSet().length == 4 &&
                    MatchPair.encode(ex.pairs) == ex.answer,
                'Pairs: ${ex.id}',
              );
            case ExerciseType.wordBank:
            case ExerciseType.listeningWordBank:
            case ExerciseType.dictation:
            case ExerciseType.translateInput:
            case ExerciseType.speaking:
              require(ex.sentence == ex.answer, 'Sentence answer: ${ex.id}');
          }
        }
      }
    }
    stdout.writeln('$track: ${course.orderedLessons.length} lessons validated');
  }
}
