import 'dart:convert';

import 'content_catalog.dart';

import 'package:mother_pattern_schema/mother_pattern_schema.dart';

const _exerciseTypes = {
  'translateChoice',
  'wordBank',
  'listeningChoice',
  'fillBlank',
  'speaking',
  'matchPairs',
  'listeningWordBank',
  'dictation',
  'translateInput',
};

const _languages = {'english', 'chinese', 'sanskrit'};

/// 发布前校验。通过返回 null，否则返回给管理员看的原因。
String? validateContentPack(String packId, String text) {
  final spec = contentPackById(packId);
  if (spec == null) return '未知内容包';
  if (utf8.encode(text).length > maxContentJsonBytes) return '内容过大';

  final decoded = _decodeObject(text);
  if (decoded == null) return '内容必须是 JSON 对象';

  return switch (spec.kind) {
    'course' => _validateCourse(decoded, spec.courseId!),
    'practice' => _validatePractice(decoded, spec.skill!),
    'dialogues' =>
      spec.id == 'dialogues/units'
          ? _validateDialogues(decoded)
          : _validateTasks(decoded),
    'phonetics' => _validatePhonetics(decoded),
    _ => '未知内容包',
  };
}

Map<String, dynamic>? _decodeObject(String text) {
  try {
    final value = jsonDecode(text);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  } catch (_) {
    return null;
  }
}

String? _validateCourse(Map<String, dynamic> json, String courseId) {
  final patternError = validateCourseIdentityAndPatterns(json, courseId);
  if (patternError != null) return patternError;
  if (json['id'] != courseId) return '课程 id 须为 $courseId';
  if (json['title'] is! String) return '课程缺少 title';
  final language = json['language'];
  if (language != null && !_languages.contains(language)) return '课程语言无效';
  final explanation = json['explanationLanguage'];
  if (explanation != null && explanation is! String) {
    return 'explanationLanguage 须为字符串';
  }
  final units = json['units'];
  if (units is! List) return '课程缺少 units';
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit is! Map) return 'units[$i] 须为对象';
    final error = _validateUnit(Map<String, dynamic>.from(unit), 'units[$i]');
    if (error != null) return error;
  }
  return null;
}

String? _validateUnit(Map<String, dynamic> json, String where) {
  if (json['id'] is! String || (json['id'] as String).isEmpty) {
    return '$where 缺少 id';
  }
  if (json['title'] is! String) return '$where 缺少 title';
  if (json['description'] is! String) return '$where 缺少 description';
  final lessons = json['lessons'];
  if (lessons is! List) return '$where 缺少 lessons';
  for (var i = 0; i < lessons.length; i++) {
    final lesson = lessons[i];
    if (lesson is! Map) return '$where.lessons[$i] 须为对象';
    final error = _validateLesson(
      Map<String, dynamic>.from(lesson),
      '$where.lessons[$i]',
    );
    if (error != null) return error;
  }
  return null;
}

String? _validateLesson(Map<String, dynamic> json, String where) {
  if (json['id'] is! String || (json['id'] as String).isEmpty) {
    return '$where 缺少 id';
  }
  if (json['title'] is! String) return '$where 缺少 title';
  final exercises = json['exercises'];
  if (exercises is! List) return '$where 缺少 exercises';
  for (var i = 0; i < exercises.length; i++) {
    final exercise = exercises[i];
    if (exercise is! Map) return '$where.exercises[$i] 须为对象';
    final error = _validateExercise(
      Map<String, dynamic>.from(exercise),
      '$where.exercises[$i]',
    );
    if (error != null) return error;
  }
  final training = json['patternTraining'];
  if (training != null) {
    if (training is! Map) return '$where.patternTraining 须为对象';
    final error = _validatePatternTraining(
      Map<String, dynamic>.from(training),
      '$where.patternTraining',
    );
    if (error != null) return error;
  }
  return null;
}

String? _validatePatternTraining(Map<String, dynamic> json, String where) {
  for (final key in ['id', 'frame', 'meaning', 'slotRule', 'prefix']) {
    if (json[key] is! String ||
        (json[key] as String).trim().isEmpty ||
        (['id', 'frame', 'prefix'].contains(key) &&
            !_patternEnglish(json[key] as String))) {
      return '$where.$key 须为非空字符串，目标句型须为英语';
    }
  }
  final version = json['version'];
  if (version is! int || version < 1) return '$where.version 须为正整数';
  final suffix = json['suffix'] ?? '';
  if (suffix is! String || !_patternEnglish(suffix)) {
    return '$where.suffix 须为英文字符串';
  }
  final seen = <String>{};
  const phases = {
    'examples': (3, 'speaking'),
    'substitution': (2, 'wordBank'),
    'recall': (2, 'translateInput'),
    'transfer': (2, 'translateInput'),
    'review': (4, 'translateInput'),
  };
  for (final phase in phases.entries) {
    final list = json[phase.key];
    if (list is! List ||
        (phase.key == 'review'
            ? list.length < phase.value.$1
            : list.length != phase.value.$1)) {
      return '$where.${phase.key} 题目数量无效';
    }
    for (var i = 0; i < list.length; i++) {
      final value = list[i];
      final location = '$where.${phase.key}[$i]';
      if (value is! Map) return '$location 须为对象';
      final exercise = Map<String, dynamic>.from(value);
      final error = _validateExercise(exercise, location);
      if (error != null) return error;
      if (!seen.add(exercise['id'] as String)) return '$location id 重复';
      if (exercise['type'] != phase.value.$2) return '$location 题型无效';
      if ((exercise['language'] ?? 'english') != 'english') {
        return '$location 须为英语';
      }
      if ((exercise['prompt'] as String).trim().isEmpty) {
        return '$location prompt 须为非空字符串';
      }
      for (final text in [
        exercise['sentence'],
        exercise['answer'],
        ...?(exercise['acceptedAnswers'] as List?),
        ...?(exercise['tokens'] as List?),
      ]) {
        if ((text as String).trim().isEmpty || !_patternEnglish(text)) {
          return '$location 须为非空英文内容';
        }
      }
      if (phase.key == 'substitution') {
        final tokens = exercise['tokens'];
        if (tokens is! List ||
            tokens.isEmpty ||
            _normalizePatternAnswer(
                  tokens.join(exercise['tokenSeparator'] as String? ?? ' '),
                ) !=
                _normalizePatternAnswer(exercise['answer'] as String)) {
          return '$location tokens 须还原答案';
        }
      }
      if (phase.key == 'examples') {
        final sentence = exercise['sentence'] as String;
        final prefix = json['prefix'] as String;
        if (!sentence.startsWith(prefix) ||
            !sentence.endsWith(suffix) ||
            sentence.length <= prefix.length + suffix.length ||
            sentence
                .substring(prefix.length, sentence.length - suffix.length)
                .trim()
                .isEmpty) {
          return '$location 须包含前缀、替换部分及后缀';
        }
      }
    }
  }
  return null;
}

bool _patternEnglish(String text) => !RegExp(
  r'[\u3400-\u9fff\u3040-\u30ff\u0900-\u097f\u0400-\u04ff\u0600-\u06ff]',
).hasMatch(text);

String _normalizePatternAnswer(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll(RegExp("[‘’´`]"), "'")
    .replaceAll(
      RegExp(r'[\[\].,;:!?。，、；：！？．…·・•~～—–‐‑‒―"“”„«»「」『』()（）-]+'),
      ' ',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String? _validateExercise(Map<String, dynamic> json, String where) {
  if (json['id'] is! String || (json['id'] as String).isEmpty) {
    return '$where 缺少 id';
  }
  if (!_exerciseTypes.contains(json['type'])) return '$where 题型无效';
  for (final key in ['prompt', 'sentence', 'answer']) {
    if (json[key] is! String) return '$where 缺少 $key';
  }
  final options = json['options'];
  if (options != null && !_stringList(options)) {
    return '$where options 须为字符串列表';
  }
  final accepted = json['acceptedAnswers'];
  if (accepted != null && !_stringList(accepted)) {
    return '$where acceptedAnswers 须为字符串列表';
  }
  final tokens = json['tokens'];
  if (tokens != null && !_stringList(tokens)) {
    return '$where tokens 须为字符串列表';
  }
  final language = json['language'];
  if (language != null && !_languages.contains(language)) {
    return '$where 语言无效';
  }
  final blank = json['sentenceWithBlank'];
  if (blank != null && blank is! String) {
    return '$where sentenceWithBlank 须为字符串';
  }
  final support = json['support'];
  if (support != null && support is! String) return '$where support 须为字符串';
  final separator = json['tokenSeparator'];
  if (separator != null && separator is! String) {
    return '$where tokenSeparator 须为字符串';
  }
  final pairs = json['pairs'];
  if (pairs != null) {
    if (pairs is! List) return '$where pairs 须为列表';
    for (var i = 0; i < pairs.length; i++) {
      final pair = pairs[i];
      if (pair is! Map) return '$where.pairs[$i] 须为对象';
      if (pair['left'] is! String || pair['right'] is! String) {
        return '$where.pairs[$i] 缺少 left 或 right';
      }
    }
  }
  return null;
}

String? _validatePractice(Map<String, dynamic> json, String skill) {
  if (json['skill'] != skill) return 'skill 须为 $skill';
  if (json['title'] != null && json['title'] is! String) return 'title 须为字符串';
  final exercises = json['exercises'];
  if (exercises is! List) return '缺少 exercises';
  for (var i = 0; i < exercises.length; i++) {
    final exercise = exercises[i];
    if (exercise is! Map) return 'exercises[$i] 须为对象';
    final error = _validateExercise(
      Map<String, dynamic>.from(exercise),
      'exercises[$i]',
    );
    if (error != null) return error;
  }
  return null;
}

String? _validateDialogues(Map<String, dynamic> json) {
  for (final entry in json.entries) {
    final lines = entry.value;
    if (lines is! List) return '${entry.key} 须为台词列表';
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line is! Map) return '${entry.key}[$i] 须为对象';
      if (line['speaker'] is! int) return '${entry.key}[$i] speaker 须为整数';
      if (line['english'] is! String || line['chinese'] is! String) {
        return '${entry.key}[$i] 缺少 english 或 chinese';
      }
    }
  }
  return null;
}

String? _validateTasks(Map<String, dynamic> json) {
  for (final entry in json.entries) {
    final task = entry.value;
    if (task is! Map) return '${entry.key} 须为对象';
    for (final key in ['question', 'answer', 'sentence']) {
      if (task[key] is! String) return '${entry.key} 缺少 $key';
    }
    if (!_stringList(task['options'])) {
      return '${entry.key} options 须为字符串列表';
    }
    final scenario = task['scenario'];
    if (scenario != null && scenario is! String) {
      return '${entry.key} scenario 须为字符串';
    }
  }
  return null;
}

String? _validatePhonetics(Map<String, dynamic> json) {
  for (final entry in json.entries) {
    if (entry.key.isEmpty) return '音标词条不能为空';
    if (entry.value is! String) return '${entry.key} 的音标须为字符串';
  }
  return null;
}

bool _stringList(Object? value) =>
    value is List && value.every((item) => item is String);
