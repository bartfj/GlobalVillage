import 'dart:convert';

import 'content_catalog.dart';

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
  return null;
}

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
