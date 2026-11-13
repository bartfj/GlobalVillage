import 'course.dart';
import 'learning_language.dart';

/// A versioned English sentence frame with examples and staged practice.
class PatternTraining {
  final String id;
  final int version;
  final String frame;
  final String meaning;
  final String slotRule;
  final String prefix;
  final String suffix;
  final List<Exercise> examples;
  final List<Exercise> substitution;
  final List<Exercise> recall;
  final List<Exercise> transfer;
  final List<Exercise> review;

  const PatternTraining({
    required this.id,
    required this.version,
    required this.frame,
    required this.meaning,
    required this.slotRule,
    required this.prefix,
    this.suffix = '',
    required this.examples,
    required this.substitution,
    required this.recall,
    required this.transfer,
    required this.review,
  });

  List<Exercise> get exercises => [...substitution, ...recall, ...transfer];
  List<Exercise> get allExercises => [...examples, ...exercises, ...review];

  factory PatternTraining.fromJson(Map<String, dynamic> json) {
    try {
      String text(String key, {bool optional = false}) {
        final value = json[key] ?? (optional ? '' : null);
        if (value is! String ||
            (!optional && value.trim().isEmpty) ||
            (['id', 'frame', 'prefix', 'suffix'].contains(key) &&
                !_english(value))) {
          throw FormatException(
            'patternTraining.$key must contain English text',
          );
        }
        return value;
      }

      final id = text('id');
      final version = json['version'];
      if (version is! int || version < 1) {
        throw const FormatException(
          'patternTraining.version must be an integer >= 1',
        );
      }
      final seen = <String>{};
      List<Exercise> phase(
        String key,
        int count,
        ExerciseType type, {
        bool minimum = false,
      }) {
        final values = json[key];
        if (values is! List ||
            (minimum ? values.length < count : values.length != count)) {
          throw FormatException('patternTraining.$key has an invalid count');
        }
        return List<Exercise>.unmodifiable(
          values.map((value) {
            if (value is! Map<String, dynamic>) {
              throw FormatException(
                'patternTraining.$key must contain exercise objects',
              );
            }
            final exercise = Exercise.fromJson(value);
            if (exercise.id.trim().isEmpty ||
                !seen.add(exercise.id) ||
                exercise.type != type ||
                exercise.language != LearningLanguage.english) {
              throw FormatException(
                'patternTraining.$key has an invalid id, type or language',
              );
            }
            if (exercise.prompt.trim().isEmpty) {
              throw FormatException('patternTraining.$key has an empty prompt');
            }
            for (final text in [
              exercise.sentence,
              exercise.answer,
              ...exercise.acceptedAnswers,
              ...exercise.tokens,
            ]) {
              if (text.trim().isEmpty || !_english(text)) {
                throw FormatException(
                  'patternTraining.$key has empty or non-English content',
                );
              }
            }
            if (type == ExerciseType.wordBank &&
                (exercise.tokens.isEmpty ||
                    Exercise.normalizeAnswer(
                          exercise.tokens.join(exercise.tokenSeparator),
                        ) !=
                        Exercise.normalizeAnswer(exercise.answer))) {
              throw const FormatException(
                'patternTraining wordBank tokens must reconstruct the answer',
              );
            }
            return exercise;
          }),
        );
      }

      final training = PatternTraining(
        id: id,
        version: version,
        frame: text('frame'),
        meaning: text('meaning'),
        slotRule: text('slotRule'),
        prefix: text('prefix'),
        suffix: text('suffix', optional: true),
        examples: phase('examples', 3, ExerciseType.speaking),
        substitution: phase('substitution', 2, ExerciseType.wordBank),
        recall: phase('recall', 2, ExerciseType.translateInput),
        transfer: phase('transfer', 2, ExerciseType.translateInput),
        review: phase('review', 4, ExerciseType.translateInput, minimum: true),
      );
      for (final example in training.examples) {
        final sentence = example.sentence;
        if (!sentence.startsWith(training.prefix) ||
            !sentence.endsWith(training.suffix) ||
            sentence.length <=
                training.prefix.length + training.suffix.length ||
            sentence
                .substring(
                  training.prefix.length,
                  sentence.length - training.suffix.length,
                )
                .trim()
                .isEmpty) {
          throw const FormatException(
            'patternTraining example must contain prefix, a slot and suffix',
          );
        }
      }
      return training;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid patternTraining: $error');
    }
  }

  // Permit Latin accents and typographic punctuation, reject other scripts.
  static bool _english(String text) => !RegExp(
    r'[\u3400-\u9fff\u3040-\u30ff\u0900-\u097f\u0400-\u04ff\u0600-\u06ff]',
  ).hasMatch(text);
}
