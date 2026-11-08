import '../../data/models/course.dart';
import '../../data/models/learning_language.dart';

final _hanzi = RegExp(r'[\u4e00-\u9fff]');
final _devanagari = RegExp(r'[\u0900-\u097F]');
final _quotedIast = RegExp(r'[“"]([^”"]+)[”"]');

/// 梵文题在反馈栏展示的正确答案：天城体 · IAST · 中文（有则加入）。
String formatCorrectAnswerForDisplay(Exercise exercise) {
  final base = exercise.type == ExerciseType.matchPairs
      ? MatchPair.formatForDisplay(exercise.answer)
      : exercise.answer;

  if (exercise.language != LearningLanguage.sanskrit) {
    return base;
  }

  if (exercise.type == ExerciseType.matchPairs) {
    return base;
  }

  final parts = <String>[];

  void addPart(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return;
    if (parts.contains(text)) return;
    parts.add(text);
  }

  final support = exercise.support?.trim();
  if (support != null && support.isNotEmpty) {
    addPart(support);
  }

  final iast = _sanskritIast(exercise);
  addPart(iast);

  final chinese = _sanskritChinese(exercise);
  addPart(chinese);

  if (parts.isEmpty) return base;
  return parts.join(' · ');
}

String? _sanskritIast(Exercise exercise) {
  for (final candidate in [exercise.answer, exercise.sentence]) {
    final text = candidate.trim();
    if (text.isEmpty) continue;
    if (_hanzi.hasMatch(text)) continue;
    if (_devanagari.hasMatch(text) && !_looksLikeIast(text)) continue;
    if (_looksLikeIast(text) || !_devanagari.hasMatch(text)) return text;
  }

  final quoted = _quotedIast.firstMatch(exercise.prompt);
  if (quoted != null) {
    final text = quoted.group(1)!.trim();
    if (text.isNotEmpty && !_hanzi.hasMatch(text)) return text;
  }

  return null;
}

String? _sanskritChinese(Exercise exercise) {
  for (final candidate in [exercise.answer, exercise.sentence]) {
    final text = candidate.trim();
    if (text.isNotEmpty && _hanzi.hasMatch(text)) return text;
  }

  var sep = exercise.prompt.indexOf('：');
  var skip = 1;
  if (sep < 0) {
    sep = exercise.prompt.indexOf(': ');
    skip = 2;
  }
  if (sep < 0) return null;

  final meaning = exercise.prompt.substring(sep + skip).trim();
  if (meaning.isEmpty) return null;
  if (!_hanzi.hasMatch(meaning)) return null;
  return meaning;
}

bool _looksLikeIast(String text) {
  return RegExp(r'[a-zA-ZāīūṛṝḷḹṅñṭḍṇśṣṃḥĀĪŪṚṜḶḸṄÑṬḌṆŚṢṂḤ]').hasMatch(text);
}
