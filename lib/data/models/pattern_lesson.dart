import 'course.dart';
import 'learning_language.dart';

enum PatternLessonKind { pattern, dialogue }

enum PatternPhaseType { listening, chunks, repeat, recall, scenario }

class PatternDialogueTurn {
  final String speaker;
  final String text;
  final String translation;
  final String audioId;

  const PatternDialogueTurn({
    required this.speaker,
    required this.text,
    required this.translation,
    required this.audioId,
  });

  factory PatternDialogueTurn.fromJson(Map<String, dynamic> json) =>
      PatternDialogueTurn(
        speaker: _text(json, 'speaker'),
        text: _text(json, 'text', english: true),
        translation: _text(json, 'translation'),
        audioId: _id(json, 'audioId'),
      );
}

class PatternVocabulary {
  final String text;
  final String meaning;
  final String audioId;

  const PatternVocabulary({
    required this.text,
    required this.meaning,
    required this.audioId,
  });

  factory PatternVocabulary.fromJson(Map<String, dynamic> json) =>
      PatternVocabulary(
        text: _text(json, 'text', english: true),
        meaning: _text(json, 'meaning'),
        audioId: _id(json, 'audioId'),
      );
}

class PatternPhase {
  final PatternPhaseType type;
  final List<String> exerciseIds;

  const PatternPhase({required this.type, required this.exerciseIds});

  factory PatternPhase.fromJson(Map<String, dynamic> json) => PatternPhase(
    type: PatternPhaseType.values.byName(_text(json, 'type')),
    exerciseIds: List<String>.unmodifiable(_strings(json, 'exerciseIds')),
  );
}

/// Teaching material and phase references for the independent listening and
/// speaking pack. Scored exercises stay in Lesson.exercises.
class PatternLesson {
  final String id;
  final int version;
  final PatternLessonKind kind;
  final String frame;
  final String meaning;
  final String slotRule;
  final List<String> limitations;
  final List<PatternDialogueTurn> dialogue;
  final List<PatternVocabulary> vocabulary;
  final List<Exercise> examples;
  final List<PatternPhase> phases;
  final List<Exercise> review;
  final List<String> patternIds;

  const PatternLesson({
    required this.id,
    required this.version,
    required this.kind,
    required this.frame,
    required this.meaning,
    required this.slotRule,
    required this.limitations,
    required this.dialogue,
    required this.vocabulary,
    required this.examples,
    required this.phases,
    required this.review,
    required this.patternIds,
  });

  /// Four responses attempted without a displayed model answer.
  List<String> get independentExerciseIds => List<String>.unmodifiable([
    for (final phase in phases)
      if (phase.type == PatternPhaseType.recall ||
          phase.type == PatternPhaseType.scenario)
        ...phase.exerciseIds,
  ]);

  /// Supplementary teaching and rotating review exercises only.
  List<Exercise> get allExercises => [...examples, ...review];

  PatternPhaseType? phaseForExercise(String exerciseId) {
    for (final phase in phases) {
      if (phase.exerciseIds.contains(exerciseId)) return phase.type;
    }
    return null;
  }

  factory PatternLesson.fromJson(Map<String, dynamic> json) {
    try {
      final version = json['version'];
      if (version is! int || version < 1) {
        throw const FormatException(
          'patternLesson.version must be an integer >= 1',
        );
      }
      final result = PatternLesson(
        id: _id(json, 'id'),
        version: version,
        kind: PatternLessonKind.values.byName(_text(json, 'kind')),
        frame: _text(json, 'frame', english: true),
        meaning: _text(json, 'meaning'),
        slotRule: _text(json, 'slotRule'),
        limitations: List<String>.unmodifiable(_strings(json, 'limitations')),
        dialogue: _objects(json, 'dialogue', PatternDialogueTurn.fromJson),
        vocabulary: _objects(json, 'vocabulary', PatternVocabulary.fromJson),
        examples: _objects(json, 'examples', Exercise.fromJson),
        phases: _objects(json, 'phases', PatternPhase.fromJson),
        review: _objects(json, 'review', Exercise.fromJson),
        patternIds: List<String>.unmodifiable(_strings(json, 'patternIds')),
      );
      if (result.dialogue.length < 2 ||
          result.vocabulary.isEmpty ||
          result.limitations.isEmpty ||
          result.patternIds.isEmpty ||
          result.patternIds.toSet().length != result.patternIds.length ||
          result.patternIds.any((id) => !_validId(id))) {
        throw const FormatException(
          'patternLesson needs dialogue, vocabulary, limitations and pattern IDs',
        );
      }
      if (result.kind == PatternLessonKind.pattern) {
        if (result.examples.length != 3 ||
            result.review.length < 4 ||
            result.patternIds.length != 1 ||
            result.patternIds.single != result.id) {
          throw const FormatException(
            'patternLesson needs three examples, four review tasks and its own pattern ID',
          );
        }
      } else if (result.examples.isNotEmpty ||
          result.review.isNotEmpty ||
          result.patternIds.length != 3) {
        throw const FormatException(
          'dialogue metadata must reference three taught patterns without supplementary tasks',
        );
      }
      final seen = <String>{};
      for (final exercise in result.allExercises) {
        _validateExercise(exercise);
        if (!seen.add(exercise.id) ||
            exercise.type != ExerciseType.speaking ||
            exercise.speakingMode !=
                (result.review.contains(exercise)
                    ? SpeakingMode.scenario
                    : SpeakingMode.repeat)) {
          throw const FormatException(
            'patternLesson supplementary exercise has an invalid ID, type or mode',
          );
        }
      }
      return result;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid patternLesson: $error');
    }
  }

  /// Rejects incomplete/duplicated phase references and incompatible exercises.
  /// Called by Lesson.fromJson so malformed overrides cannot reach a session.
  void validateExercises(List<Exercise> exercises) {
    final expected = kind == PatternLessonKind.pattern
        ? const [
            PatternPhaseType.listening,
            PatternPhaseType.chunks,
            PatternPhaseType.repeat,
            PatternPhaseType.recall,
            PatternPhaseType.scenario,
          ]
        : const [
            PatternPhaseType.listening,
            PatternPhaseType.chunks,
            PatternPhaseType.repeat,
            PatternPhaseType.scenario,
          ];
    if (exercises.length != 10 || phases.length != expected.length) {
      throw const FormatException(
        'patternLesson requires ten scored exercises and all ordered phases',
      );
    }
    final byId = <String, Exercise>{};
    for (final exercise in [...exercises, ...allExercises]) {
      _validateExercise(exercise);
      if (byId.containsKey(exercise.id)) {
        throw const FormatException('patternLesson duplicate exercise ID');
      }
      byId[exercise.id] = exercise;
    }
    final seen = <String>{};
    for (var i = 0; i < phases.length; i++) {
      final phase = phases[i];
      final count =
          kind == PatternLessonKind.dialogue &&
              phase.type == PatternPhaseType.scenario
          ? 4
          : 2;
      if (phase.type != expected[i] || phase.exerciseIds.length != count) {
        throw const FormatException(
          'patternLesson has invalid phase order or count',
        );
      }
      for (final exerciseId in phase.exerciseIds) {
        final exercise = byId[exerciseId];
        if (exercise == null ||
            !exercises.contains(exercise) ||
            !seen.add(exerciseId)) {
          throw const FormatException(
            'patternLesson phase reference is absent or duplicated',
          );
        }
        final valid = switch (phase.type) {
          PatternPhaseType.listening =>
            exercise.type == ExerciseType.listeningChoice,
          PatternPhaseType.chunks => exercise.type == ExerciseType.wordBank,
          PatternPhaseType.repeat =>
            exercise.type == ExerciseType.speaking &&
                exercise.speakingMode == SpeakingMode.repeat,
          PatternPhaseType.recall =>
            exercise.type == ExerciseType.translateInput,
          PatternPhaseType.scenario =>
            exercise.type == ExerciseType.speaking &&
                exercise.speakingMode == SpeakingMode.scenario,
        };
        if (!valid) {
          throw const FormatException(
            'patternLesson exercise is incompatible with its phase',
          );
        }
      }
    }
    if (seen.length != exercises.length) {
      throw const FormatException(
        'patternLesson phase references must cover all exercises',
      );
    }
    final orderedIds = phases.expand((phase) => phase.exerciseIds).toList();
    for (var i = 0; i < exercises.length; i++) {
      if (exercises[i].id != orderedIds[i]) {
        throw const FormatException(
          'patternLesson exercises must follow the declared phase order',
        );
      }
    }
  }
}

void _validateExercise(Exercise exercise) {
  if (!_validId(exercise.id) ||
      exercise.language != LearningLanguage.english ||
      exercise.prompt.trim().isEmpty) {
    throw const FormatException(
      'patternLesson exercise needs an mp_ ID, prompt and English language',
    );
  }
  for (final value in [
    exercise.answer,
    exercise.sentence,
    ...exercise.acceptedAnswers,
    ...exercise.tokens,
    ...exercise.options,
  ]) {
    if (value.trim().isEmpty || !_english(value)) {
      throw const FormatException(
        'patternLesson exercise contains empty or non-English content',
      );
    }
  }
  if (exercise.type == ExerciseType.wordBank &&
      (exercise.tokens.isEmpty ||
          Exercise.normalizeAnswer(
                exercise.tokens.join(exercise.tokenSeparator),
              ) !=
              Exercise.normalizeAnswer(exercise.answer))) {
    throw const FormatException(
      'patternLesson chunks must reconstruct the answer',
    );
  }
  if (exercise.type == ExerciseType.listeningChoice &&
      (exercise.options.length != 4 ||
          exercise.options.map(Exercise.normalizeAnswer).toSet().length != 4 ||
          Exercise.normalizeAnswer(exercise.sentence) !=
              Exercise.normalizeAnswer(exercise.answer) ||
          !exercise.options.contains(exercise.answer))) {
    throw const FormatException(
      'patternLesson listening needs four distinct options and matching audio/answer text',
    );
  }
  if (exercise.speakingMode == SpeakingMode.scenario &&
      exercise.type != ExerciseType.speaking) {
    throw const FormatException(
      'scenario speaking mode requires a speaking exercise',
    );
  }
  if (exercise.audioId != null && !_validId(exercise.audioId!)) {
    throw const FormatException('patternLesson audio ID must start with mp_');
  }
}

String _text(Map<String, dynamic> json, String key, {bool english = false}) {
  final value = json[key];
  if (value is! String ||
      value.trim().isEmpty ||
      (english && !_english(value))) {
    throw FormatException(
      'patternLesson.$key must contain ${english ? 'English ' : ''}text',
    );
  }
  return value;
}

bool _validId(String value) => RegExp(r'^mp_[a-z0-9_]+$').hasMatch(value);

String _id(Map<String, dynamic> json, String key) {
  final value = _text(json, key);
  if (!_validId(value)) {
    throw FormatException('patternLesson.$key must be an mp_ ID');
  }
  return value;
}

List<String> _strings(Map<String, dynamic> json, String key) {
  final values = json[key];
  if (values is! List || values.any((v) => v is! String || v.trim().isEmpty)) {
    throw FormatException(
      'patternLesson.$key must be a list of nonempty strings',
    );
  }
  return values.cast<String>();
}

List<T> _objects<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final values = json[key];
  if (values is! List || values.any((v) => v is! Map<String, dynamic>)) {
    throw FormatException('patternLesson.$key must be a list of objects');
  }
  return List<T>.unmodifiable(
    values.map((value) => parse(value as Map<String, dynamic>)),
  );
}

bool _english(String text) => !RegExp(
  r'[\u3400-\u9fff\u3040-\u30ff\u0900-\u097f\u0400-\u04ff\u0600-\u06ff]',
).hasMatch(text);
