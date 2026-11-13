/// Pure JSON validation shared by the server publication boundary and client
/// overlays. This dependency-free package stays inside the server build context.
String? validateCourseIdentityAndPatterns(
  Map<String, dynamic> json,
  String courseId,
) {
  try {
    if (json['id'] != courseId) _bad('课程 id 须为 $courseId');
    if (courseId == 'motherPattern') {
      _validateIndependent(json);
    } else {
      // Only main entities reserve the namespace. Cached legacy supplemental
      // patternTraining content remains readable for backwards compatibility.
      final units = json['units'];
      if (units is List) {
        for (final unit in units.whereType<Map>()) {
          _ordinaryId(unit['id']);
          final lessons = unit['lessons'];
          if (lessons is! List) continue;
          for (final lesson in lessons.whereType<Map>()) {
            _ordinaryId(lesson['id']);
            if (lesson['patternLesson'] != null) {
              _bad('独立 patternLesson 只能用于 motherPattern 课程');
            }
            final exercises = lesson['exercises'];
            if (exercises is List) {
              for (final exercise in exercises.whereType<Map>()) {
                _ordinaryId(exercise['id']);
              }
            }
          }
        }
      }
    }
    return null;
  } on FormatException catch (error) {
    return error.message;
  }
}

void _ordinaryId(Object? id) {
  if (id is String && id.startsWith('mp_')) {
    _bad('普通课程主实体不得使用保留的 mp_ ID');
  }
}

const _patternOrder = [
  'mp_am',
  'mp_name',
  'mp_this',
  'mp_like',
  'mp_dont_like',
  'mp_do_you_like',
  'mp_need',
  'mp_want',
  'mp_would_like',
  'mp_what_this',
  'mp_price',
  'mp_can_have',
];
final _mpId = RegExp(r'^mp_[a-z0-9_]+$');
final _nonEnglish = RegExp(
  r'[\u3400-\u9fff\u3040-\u30ff\u0900-\u097f\u0400-\u04ff\u0600-\u06ff]',
);

void _validateIndependent(Map<String, dynamic> json) {
  _text(json, 'title');
  if (json['language'] != 'english' ||
      json['explanationLanguage'] != 'chinese') {
    _bad('motherPattern 须为英语课程和中文解释');
  }
  final units = _objects(json, 'units');
  if (units.length != 4) _bad('motherPattern 须有四个单元');
  final ids = <String>{};
  final taught = <String>{};
  for (var u = 0; u < units.length; u++) {
    final unit = units[u];
    final unitId = _entity(unit, 'id', ids);
    if (unitId != 'mp_u${u + 1}') _bad('motherPattern 单元顺序无效');
    _text(unit, 'title');
    _text(unit, 'description');
    final lessons = _objects(unit, 'lessons');
    if (lessons.length != 4) _bad('$unitId 须有四课');
    for (var l = 0; l < lessons.length; l++) {
      final lesson = lessons[l];
      final lessonId = _entity(lesson, 'id', ids);
      if (lessonId != '${unitId}l${l + 1}') _bad('$unitId 课时顺序无效');
      _text(lesson, 'title');
      if (lesson['patternTraining'] != null) _bad('独立课程不得包含旧 patternTraining');
      final metadata = _object(
        lesson['patternLesson'],
        '$lessonId.patternLesson',
      );
      final patternId = _entity(metadata, 'id', ids);
      final version = metadata['version'];
      if (version is! int || version < 1) _bad('$lessonId 句型版本须为正整数');
      final dialogue = l == 3;
      if (metadata['kind'] != (dialogue ? 'dialogue' : 'pattern')) {
        _bad('$lessonId 句型或对话课顺序无效');
      }
      _text(metadata, 'frame', english: true);
      _text(metadata, 'meaning');
      _text(metadata, 'slotRule');
      if (_strings(metadata, 'limitations').isEmpty) _bad('$lessonId 缺少用法限制');
      final patterns = _strings(metadata, 'patternIds');
      if (patterns.toSet().length != patterns.length) _bad('$lessonId 句型引用重复');
      if (!dialogue) {
        final expectedId = _patternOrder[u * 3 + l];
        if (patternId != expectedId ||
            patterns.length != 1 ||
            patterns.single != patternId) {
          _bad('$lessonId 教学句型 ID 或顺序无效');
        }
        taught.add(patternId);
      } else {
        if (patternId != 'mp_dialogue_u${u + 1}' ||
            patterns.length != 3 ||
            patterns.any((id) => !taught.contains(id))) {
          _bad('$lessonId 对话只能引用三个已教句型');
        }
      }
      final exercises = _objects(lesson, 'exercises');
      final examples = _objects(metadata, 'examples');
      final review = _objects(metadata, 'review');
      if (exercises.length != 10 ||
          (dialogue
              ? examples.isNotEmpty || review.isNotEmpty
              : examples.length != 3 || review.length < 4)) {
        _bad('$lessonId 计分/范句/复习题数量无效');
      }
      for (final exercise in [...exercises, ...examples, ...review]) {
        _exercise(exercise, lessonId, ids);
      }
      for (final example in examples) {
        if (example['type'] != 'speaking' ||
            (example['speakingMode'] ?? 'repeat') != 'repeat') {
          _bad('$lessonId 范句须为跟读');
        }
      }
      for (final task in review) {
        if (task['type'] != 'speaking' || task['speakingMode'] != 'scenario') {
          _bad('$lessonId 复习须为场景口述');
        }
      }
      _phases(metadata, exercises, dialogue);
      final turns = _objects(metadata, 'dialogue');
      if (turns.length < 2) _bad('$lessonId 缺少短对话');
      for (final turn in turns) {
        _text(turn, 'speaker');
        _text(turn, 'text', english: true);
        _text(turn, 'translation');
        _instructionAudio(turn, lessonId, ids);
      }
      final vocabulary = _objects(metadata, 'vocabulary');
      if (vocabulary.isEmpty) _bad('$lessonId 缺少词汇');
      for (final word in vocabulary) {
        _text(word, 'text', english: true);
        _text(word, 'meaning');
        _instructionAudio(word, lessonId, ids);
      }
    }
  }
}

void _instructionAudio(
  Map<String, dynamic> item,
  String lessonId,
  Set<String> ids,
) {
  final id = _entity(item, 'audioId', ids);
  if (!id.startsWith('${lessonId}_')) _bad('$lessonId 教学音频 ID 须属于当前课');
}

void _exercise(Map<String, dynamic> json, String lessonId, Set<String> ids) {
  final id = _entity(json, 'id', ids);
  if (!id.startsWith('${lessonId}_')) _bad('$id 题目 ID 须属于当前课');
  // audioId is the same entity's alias, not a second independently unique ID.
  if (json['audioId'] != id) _bad('$id 参考音频 ID 须与题目相同');
  if ((json['language'] ?? 'english') != 'english') _bad('$id 须为英语');
  _text(json, 'prompt');
  final answer = _text(json, 'answer', english: true);
  final sentence = _text(json, 'sentence', english: true);
  if (_normalize(answer).isEmpty ||
      _normalize(sentence) != _normalize(answer)) {
    _bad('$id 参考音频 sentence 须与 answer 一致');
  }
  for (final key in ['acceptedAnswers', 'tokens', 'options']) {
    if (json[key] == null) continue;
    for (final text in _strings(json, key)) {
      if (_nonEnglish.hasMatch(text) || _normalize(text).isEmpty) {
        _bad('$id.$key 须为非空英文内容');
      }
    }
  }
  final separator = json['tokenSeparator'];
  if (separator != null && separator is! String) {
    _bad('$id.tokenSeparator 须为字符串');
  }
  final mode = json['speakingMode'] ?? 'repeat';
  if (!['repeat', 'scenario'].contains(mode) ||
      (mode == 'scenario' && json['type'] != 'speaking')) {
    _bad('$id 口述模式无效');
  }
  switch (json['type']) {
    case 'wordBank':
      final tokens = _strings(json, 'tokens');
      if (tokens.isEmpty ||
          _normalize(tokens.join(separator as String? ?? ' ')) !=
              _normalize(answer)) {
        _bad('$id 句块须还原答案');
      }
    case 'listeningChoice':
      final options = _strings(json, 'options');
      if (options.length != 4 ||
          options.map(_normalize).toSet().length != 4 ||
          !options.contains(answer)) {
        _bad('$id 听力须有四个不同选项及正确答案');
      }
    case 'speaking':
    case 'translateInput':
      break;
    default:
      _bad('$id 独立课程题型无效');
  }
}

void _phases(
  Map<String, dynamic> metadata,
  List<Map<String, dynamic>> exercises,
  bool dialogue,
) {
  final phases = _objects(metadata, 'phases');
  final expected = [
    'listening',
    'chunks',
    'repeat',
    if (!dialogue) 'recall',
    'scenario',
  ];
  if (phases.length != expected.length) _bad('patternLesson 阶段数量无效');
  var offset = 0;
  final seen = <String>{};
  for (var i = 0; i < phases.length; i++) {
    final phase = phases[i];
    final type = expected[i];
    final refs = _strings(phase, 'exerciseIds');
    if (phase['type'] != type ||
        refs.length != (dialogue && type == 'scenario' ? 4 : 2)) {
      _bad('patternLesson 阶段顺序或题数无效');
    }
    for (final ref in refs) {
      final exercise = exercises[offset++];
      if (exercise['id'] != ref || !seen.add(ref)) {
        _bad('patternLesson 阶段引用缺失、重复或顺序无效');
      }
      final compatible = switch (type) {
        'listening' => exercise['type'] == 'listeningChoice',
        'chunks' => exercise['type'] == 'wordBank',
        'repeat' =>
          exercise['type'] == 'speaking' &&
              (exercise['speakingMode'] ?? 'repeat') == 'repeat',
        'recall' => exercise['type'] == 'translateInput',
        'scenario' =>
          exercise['type'] == 'speaking' &&
              exercise['speakingMode'] == 'scenario',
        _ => false,
      };
      if (!compatible) _bad('patternLesson 阶段题型无效');
    }
  }
}

Never _bad(String message) => throw FormatException(message);

Map<String, dynamic> _object(Object? value, String where) {
  if (value is! Map<String, dynamic>) _bad('$where 须为对象');
  return value;
}

List<Map<String, dynamic>> _objects(Map<String, dynamic> json, String key) {
  final list = json[key];
  if (list is! List) _bad('$key 须为对象列表');
  return [for (final item in list) _object(item, key)];
}

List<String> _strings(Map<String, dynamic> json, String key) {
  final list = json[key];
  if (list is! List || list.any((v) => v is! String || v.trim().isEmpty)) {
    _bad('$key 须为非空字符串的列表');
  }
  return list.cast<String>();
}

String _text(Map<String, dynamic> json, String key, {bool english = false}) {
  final value = json[key];
  if (value is! String ||
      value.trim().isEmpty ||
      (english && _nonEnglish.hasMatch(value))) {
    _bad('$key 须为非空${english ? '英文' : ''}文本');
  }
  return value;
}

String _entity(Map<String, dynamic> json, String key, Set<String> seen) {
  final id = _text(json, key);
  if (!_mpId.hasMatch(id) || !seen.add(id)) _bad('$key 无效或全局 ID 重复: $id');
  return id;
}

// Same English answer normalization used by Exercise; alternatives need not
// equal the canonical sentence, but canonical answer audio must match it.
String _normalize(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll(RegExp("[‘’´`]"), "'")
    .replaceAll(
      RegExp(r'[\[\].,;:!?。，、；：！？．…·・•~～—–‐‑‒―"“”„«»「」『』()（）-]+'),
      ' ',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
