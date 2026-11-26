import 'package:unorm_dart/unorm_dart.dart' as unicode;

final _space = RegExp(r'\s+');
final _formatMarks = RegExp(r'\p{Default_Ignorable_Code_Point}', unicode: true);

String normalizeChineseInput(String text) =>
    unicode.nfc(text.trim()).replaceAll(_space, ' ');

const _pinyinTones = {
  'a': ['ā', 'á', 'ǎ', 'à'],
  'e': ['ē', 'é', 'ě', 'è'],
  'i': ['ī', 'í', 'ǐ', 'ì'],
  'o': ['ō', 'ó', 'ǒ', 'ò'],
  'u': ['ū', 'ú', 'ǔ', 'ù'],
  'v': ['ǖ', 'ǘ', 'ǚ', 'ǜ'],
};

String expandChinesePinyinAliases(String text) {
  final out = text.replaceAllMapped(RegExp(r'([a-zü]+)([1-4])'), (match) {
    final syllable = match[1]!.replaceAll('ü', 'v');
    // a、e 优先；ou 标在 o 上，其余复韵母标在最后一个元音上。
    var index = syllable.indexOf('a');
    if (index < 0) index = syllable.indexOf('e');
    if (index < 0) index = syllable.indexOf('ou');
    if (index < 0) {
      index = syllable.lastIndexOf(RegExp('[aeiouv]'));
    }
    if (index < 0) return match[0]!;
    final tone = _pinyinTones[syllable[index]]![int.parse(match[2]!) - 1];
    return syllable.replaceRange(index, index + 1, tone);
  });
  return out.replaceAll('v', 'ü');
}

/// Check Chinese choices and word banks in a course. Other schemas own the
/// general course shape, so this examines only well-formed exercise containers.
String? validateChineseCourseExercises(
  Map<String, dynamic> json,
  String courseId,
) {
  if (courseId != 'chineseZero' && courseId != 'chinese') return null;
  if (json['language'] != 'chinese') return '$courseId language 须为 chinese';

  final units = json['units'];
  if (units is! List) return null;
  for (final unit in units.whereType<Map>()) {
    final lessons = unit['lessons'];
    if (lessons is! List) continue;
    for (final lesson in lessons.whereType<Map>()) {
      final error = _validateExercises(lesson['exercises']);
      if (error != null) return error;
    }
  }
  return null;
}

/// Check both the current chapter format and older flat exercise banks.
String? validateChinesePracticeExercises(Map<String, dynamic> json) {
  final chapters = json['chapters'];
  if (chapters is! List || chapters.isEmpty) {
    return _validateExercises(json['exercises']);
  }
  for (final chapter in chapters.whereType<Map>()) {
    final error = _validateExercises(chapter['exercises']);
    if (error != null) return error;
  }
  return null;
}

String? _validateExercises(Object? rawExercises) {
  if (rawExercises is! List) return null;
  for (final exercise in rawExercises.whereType<Map>()) {
    final id = exercise['id'] ?? '题目';
    if (exercise['language'] != 'chinese') return '$id language 须为 chinese';
    final error = switch (exercise['type']) {
      'translateChoice' || 'listeningChoice' => _validateChoice(exercise),
      'wordBank' || 'listeningWordBank' => _validateWordBank(exercise),
      _ => null,
    };
    if (error != null) return '$id $error';
  }
  return null;
}

String _visibleKey(String text) =>
    normalizeChineseInput(text.replaceAll(_formatMarks, ''));

List<String>? _visibleStrings(Object? raw) {
  if (raw is! List ||
      raw.any((value) => value is! String || _visibleKey(value).isEmpty)) {
    return null;
  }
  return raw.cast<String>();
}

String? _validateChoice(Map exercise) {
  final options = _visibleStrings(exercise['options']);
  if (options == null || options.length != 4) return '须有四个非空选项';

  final optionKeys = options.map(
    (text) => expandChinesePinyinAliases(_visibleKey(text)),
  );
  if (optionKeys.toSet().length != 4) return '选项存在重复或等价答案';

  final answer = exercise['answer'];
  if (answer is! String) return '选项须包含正确答案';
  final target = normalizeChineseInput(answer);
  final accepted = options
      .map(normalizeChineseInput)
      .where((text) => _scoresAsAnswer(text, target));
  if (accepted.length != 1) return '须恰有一个可判为正确的选项';
  return null;
}

bool _scoresAsAnswer(String normalized, String target) =>
    normalized == target || expandChinesePinyinAliases(normalized) == target;

String? _validateWordBank(Map exercise) {
  final tokens = _visibleStrings(exercise['tokens']);
  if (tokens == null || tokens.map(_visibleKey).toSet().length < 2) {
    return '须有至少两个不同的有效词块';
  }
  final separator = exercise['tokenSeparator'] ?? ' ';
  final answer = exercise['answer'];
  if (separator is! String || answer is! String) {
    return '词块须按原顺序拼回正确答案';
  }
  final target = normalizeChineseInput(answer);
  if (normalizeChineseInput(tokens.join(separator)) != target) {
    return '词块须按原顺序拼回正确答案';
  }

  final swapped = List<String>.of(tokens);
  for (var i = 1; i < tokens.length; i++) {
    final left = tokens[i - 1];
    final right = tokens[i];
    // Equal raw concatenations cannot change the full answer after swapping.
    if ('$left$separator$right' == '$right$separator$left') continue;
    swapped[i - 1] = right;
    swapped[i] = left;
    if (!_scoresAsAnswer(
      normalizeChineseInput(swapped.join(separator)),
      target,
    )) {
      return null;
    }
    swapped[i - 1] = left;
    swapped[i] = right;
  }
  return '词块须包含可辨析的排列顺序';
}
