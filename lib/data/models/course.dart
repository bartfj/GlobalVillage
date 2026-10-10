/// 课程内容模型：Course -> Unit -> Lesson -> Exercise
library;

enum ExerciseType {
  translateChoice,
  wordBank,
  listeningChoice,
  fillBlank,
  speaking,
  matchPairs,
  listeningWordBank,
  dictation,
  translateInput,
}

class MatchPair {
  final String left;
  final String right;

  const MatchPair({required this.left, required this.right});

  factory MatchPair.fromJson(Map<String, dynamic> json) {
    return MatchPair(
      left: json['left'] as String,
      right: json['right'] as String,
    );
  }

  /// 按 left 排序后拼成判题串：`中文=英文|...`
  static String encode(Iterable<MatchPair> pairs) {
    final list = pairs.toList()..sort((a, b) => a.left.compareTo(b.left));
    return list.map((pair) => '${pair.left}=${pair.right}').join('|');
  }

  static String formatForDisplay(String answer) {
    return answer.replaceAll('|', '\n').replaceAll('=', ' — ');
  }
}

class Exercise {
  final String id;
  final ExerciseType type;

  /// 题干（中文或英文，视题型而定）
  final String prompt;

  /// 该题涉及的完整英文句子（TTS 播放 / 词块来源）
  final String sentence;

  /// 选择题选项（4 项；非选择题为 []）
  final List<String> options;

  /// 正确答案
  final String answer;
  final List<String> acceptedAnswers;

  bool accepts(String input) {
    final normalized = normalizeAnswer(input);
    if (normalized.isEmpty) return false;
    final alternatives = type == ExerciseType.translateInput
        ? acceptedAnswers
        : const <String>[];
    return [
      answer,
      ...alternatives,
    ].any((a) => normalizeAnswer(a) == normalized);
  }

  static String normalizeAnswer(String text) => text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[.!?,;]+$'), '');

  /// 填空题专用：带 ____ 的句子，其他题型为 null
  final String? sentenceWithBlank;

  /// 连线题左右项；其他题型为 []
  final List<MatchPair> pairs;

  const Exercise({
    required this.id,
    required this.type,
    required this.prompt,
    required this.sentence,
    required this.options,
    required this.answer,
    this.sentenceWithBlank,
    this.pairs = const [],
    this.acceptedAnswers = const [],
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      type: ExerciseType.values.byName(json['type'] as String),
      prompt: json['prompt'] as String,
      sentence: json['sentence'] as String,
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      answer: json['answer'] as String,
      acceptedAnswers: (json['acceptedAnswers'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      sentenceWithBlank: json['sentenceWithBlank'] as String?,
      pairs: (json['pairs'] as List<dynamic>? ?? [])
          .map((e) => MatchPair.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Lesson {
  final String id;
  final String title;
  final List<Exercise> exercises;

  const Lesson({
    required this.id,
    required this.title,
    required this.exercises,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Unit {
  final String id;
  final String title;
  final String description;
  final List<Lesson> lessons;

  const Unit({
    required this.id,
    required this.title,
    required this.description,
    required this.lessons,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      lessons: (json['lessons'] as List<dynamic>)
          .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Course {
  final String id;
  final String title;
  final List<Unit> units;

  const Course({required this.id, required this.title, required this.units});

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      title: json['title'] as String,
      units: (json['units'] as List<dynamic>)
          .map((e) => Unit.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 按顺序展开全部课程（用于解锁判定）
  List<Lesson> get orderedLessons => [for (final u in units) ...u.lessons];

  /// lesson 在全局顺序中的下标，找不到返回 -1
  int indexOfLesson(String lessonId) =>
      orderedLessons.indexWhere((l) => l.id == lessonId);

  Lesson? lessonById(String lessonId) {
    for (final lesson in orderedLessons) {
      if (lesson.id == lessonId) return lesson;
    }
    return null;
  }
}
