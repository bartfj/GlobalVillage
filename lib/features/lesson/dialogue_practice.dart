import 'dart:convert';

import 'package:flutter/services.dart';

import '../../data/models/course.dart';
import 'dialogue_script.dart';

Future<List<Exercise>> buildDialoguePractice(Unit unit) async {
  final script = await DialogueScript.load(unit.id);
  if (script == null) return [];
  final data =
      jsonDecode(
            await rootBundle.loadString(
              'assets/dialogues/application_tasks.json',
            ),
          )
          as Map<String, dynamic>;
  final task = data[unit.id] as Map<String, dynamic>?;
  final lines = script.lines;
  if (lines.map((l) => l.english).toSet().length != lines.length ||
      lines.map((l) => l.chinese).toSet().length != lines.length) {
    throw StateError('Dialogue choices must be unique: ${unit.id}');
  }
  final transcript = lines.map((l) => l.english).join('\n');
  final fallback = unit.lessons.last.exercises[4];
  final sentence = task?['sentence'] as String? ?? fallback.sentence;
  return [
    Exercise(
      id: '${unit.id}_dialogue_meaning',
      type: ExerciseType.translateChoice,
      prompt: task == null
          ? lines[1].english
          : '$transcript\n\n${task['question']}',
      sentence: lines[1].english,
      options: task == null
          ? lines.map((l) => l.chinese).toList()
          : (task['options'] as List).cast<String>(),
      answer: task?['answer'] as String? ?? lines[1].chinese,
    ),
    Exercise(
      id: '${unit.id}_dialogue_reply',
      type: ExerciseType.translateChoice,
      prompt: '选择下一句回应：${lines[0].english}',
      sentence: lines[0].english,
      options: lines.map((l) => l.english).toList(),
      answer: lines[1].english,
    ),
    Exercise(
      id: '${unit.id}_dialogue_transfer',
      type: ExerciseType.translateInput,
      prompt: task?['scenario'] as String? ?? '用本单元表达：${fallback.prompt}',
      sentence: sentence,
      options: const [],
      answer: sentence,
      acceptedAnswers: sentence == fallback.sentence
          ? fallback.acceptedAnswers
          : const [],
    ),
  ];
}
