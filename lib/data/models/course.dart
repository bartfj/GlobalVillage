/// 课程内容模型：Course -> Unit -> Lesson -> Exercise
library;

enum ExerciseType { translateChoice, wordBank, listeningChoice, fillBlank, speaking }

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

  /// 填空题专用：带 ____ 的句子，其他题型为 null
  final String? sentenceWithBlank;

  const Exercise({
    required this.id,
    required this.type,
    required this.prompt,
    required this.sentence,
    required this.options,
    required this.answer,
    this.sentenceWithBlank,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      type: ExerciseType.values.byName(json['type'] as String),
      prompt: json['prompt'] as String,
      sentence: json['sentence'] as String,
      options:
          (json['options'] as List<dynamic>? ?? [])
              .map((e) => e as String)
              .toList(),
      answer: json['answer'] as String,
      sentenceWithBlank: json['sentenceWithBlank'] as String?,
    );
  }
}

class Lesson {
  final String id;
  final String title;
  final List<Exercise> exercises;

  const Lesson({required this.id, required this.title, required this.exercises});

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
