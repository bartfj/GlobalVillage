import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/course.dart';
import '../../data/models/pattern_lesson.dart';

enum MotherPatternModality { spoken, typed, typedFallback }

class MotherPatternAttempt {
  final String exerciseId;
  final bool correct;
  final bool first;
  final bool hinted;
  final MotherPatternModality modality;

  const MotherPatternAttempt({
    required this.exerciseId,
    required this.correct,
    required this.first,
    required this.hinted,
    required this.modality,
  });

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'correct': correct,
    'first': first,
    'hinted': hinted,
    'modality': modality.name,
  };
}

class MotherPatternState {
  final String lessonId;
  final String patternId;
  final int patternVersion;
  final List<String> exerciseIds;
  final List<Exercise> queue;
  final bool isReview;
  final Set<String> independentIds;
  final Set<String> attemptedIds;
  final Set<String> firstCorrectIds;
  final Set<String> hintedIds;
  final Set<String> typedFallbackIds;
  final List<MotherPatternAttempt> attempts;
  final bool? lastAnswerCorrect;
  final bool pendingRetry;

  const MotherPatternState._({
    required this.lessonId,
    required this.patternId,
    required this.patternVersion,
    required this.exerciseIds,
    required this.queue,
    required this.isReview,
    required this.independentIds,
    this.attemptedIds = const {},
    this.firstCorrectIds = const {},
    this.hintedIds = const {},
    this.typedFallbackIds = const {},
    this.attempts = const [],
    this.lastAnswerCorrect,
    this.pendingRetry = false,
  });

  Exercise get current => queue.first;
  int get totalCount => exerciseIds.length;
  bool get checked => lastAnswerCorrect != null;
  bool get finished => queue.isEmpty;
  bool get currentHinted => !finished && hintedIds.contains(current.id);
  bool get currentTypedFallback =>
      !finished && typedFallbackIds.contains(current.id);
  double get progress =>
      totalCount == 0 ? 0 : (totalCount - queue.length) / totalCount;
  int get firstCorrectCount => firstCorrectIds.length;
  int get hintedCount => hintedIds.length;
  double get accuracy => totalCount == 0 ? 0 : firstCorrectCount / totalCount;
  bool get independentSuccess =>
      finished &&
      independentIds.isNotEmpty &&
      independentCorrectCount == independentIds.length;
  int _correctCount(
    MotherPatternModality modality, {
    bool independent = false,
  }) => attempts
      .where(
        (a) =>
            a.first &&
            a.correct &&
            a.modality == modality &&
            (!independent ||
                (independentIds.contains(a.exerciseId) &&
                    !hintedIds.contains(a.exerciseId))),
      )
      .length;
  int get firstSpokenCorrectCount =>
      _correctCount(MotherPatternModality.spoken);
  int get firstTypedCorrectCount => _correctCount(MotherPatternModality.typed);
  int get firstTypedFallbackCorrectCount =>
      _correctCount(MotherPatternModality.typedFallback);
  int get independentCorrectCount => independentIds
      .where((id) => firstCorrectIds.contains(id) && !hintedIds.contains(id))
      .length;
  int get independentSpokenCorrectCount =>
      _correctCount(MotherPatternModality.spoken, independent: true);
  int get independentTypedCorrectCount =>
      _correctCount(MotherPatternModality.typed, independent: true);
  int get independentTypedFallbackCorrectCount =>
      _correctCount(MotherPatternModality.typedFallback, independent: true);

  MotherPatternState _with({
    List<Exercise>? queue,
    Set<String>? attemptedIds,
    Set<String>? firstCorrectIds,
    Set<String>? hintedIds,
    Set<String>? typedFallbackIds,
    List<MotherPatternAttempt>? attempts,
    bool? lastAnswerCorrect,
    bool pendingRetry = false,
  }) => MotherPatternState._(
    lessonId: lessonId,
    patternId: patternId,
    patternVersion: patternVersion,
    exerciseIds: exerciseIds,
    queue: queue ?? this.queue,
    isReview: isReview,
    independentIds: independentIds,
    attemptedIds: attemptedIds ?? this.attemptedIds,
    firstCorrectIds: firstCorrectIds ?? this.firstCorrectIds,
    hintedIds: hintedIds ?? this.hintedIds,
    typedFallbackIds: typedFallbackIds ?? this.typedFallbackIds,
    attempts: attempts ?? this.attempts,
    lastAnswerCorrect: lastAnswerCorrect,
    pendingRetry: pendingRetry,
  );
}

class MotherPatternController extends StateNotifier<MotherPatternState> {
  MotherPatternController({
    required Lesson lesson,
    List<Exercise>? reviewExercises,
  }) : super(_initial(lesson, reviewExercises));

  static MotherPatternState _initial(
    Lesson lesson,
    List<Exercise>? reviewExercises,
  ) {
    final pattern = lesson.patternLesson;
    if (pattern == null) {
      throw ArgumentError('A mother-pattern lesson needs metadata');
    }
    pattern.validateExercises(lesson.exercises);
    final exercises = reviewExercises ?? lesson.exercises;
    if (reviewExercises != null &&
        (pattern.kind != PatternLessonKind.pattern ||
            exercises.length != 2 ||
            exercises.map((e) => e.id).toSet().length != 2 ||
            exercises.any((e) => !pattern.review.contains(e)))) {
      throw ArgumentError(
        'A review needs two distinct scenarios from this pattern',
      );
    }
    return MotherPatternState._(
      lessonId: lesson.id,
      patternId: pattern.id,
      patternVersion: pattern.version,
      exerciseIds: List.unmodifiable(exercises.map((e) => e.id)),
      queue: List.unmodifiable(exercises),
      isReview: reviewExercises != null,
      independentIds: Set.unmodifiable(
        reviewExercises != null
            ? exercises.map((e) => e.id)
            : pattern.independentExerciseIds,
      ),
    );
  }

  void revealHint() {
    if (state.finished || state.checked || state.currentHinted) return;
    state = state._with(
      hintedIds: Set.unmodifiable({...state.hintedIds, state.current.id}),
    );
  }

  void enableTypedFallback() {
    if (state.finished ||
        state.current.type != ExerciseType.speaking ||
        state.currentTypedFallback ||
        state.lastAnswerCorrect == true) {
      return;
    }
    state = state._with(
      typedFallbackIds: Set.unmodifiable({
        ...state.typedFallbackIds,
        state.current.id,
      }),
    );
  }

  bool submit(String answer, {required MotherPatternModality modality}) {
    if (state.finished || state.checked) {
      return state.lastAnswerCorrect ?? false;
    }
    if ((state.current.type == ExerciseType.speaking &&
            modality == MotherPatternModality.typed) ||
        (state.current.type != ExerciseType.speaking &&
            modality != MotherPatternModality.typed)) {
      throw ArgumentError(
        'Speaking uses spoken or typedFallback; other responses use typed',
      );
    }
    final id = state.current.id;
    final first = !state.attemptedIds.contains(id);
    final correct = state.current.accepts(answer);
    state = state._with(
      attemptedIds: Set.unmodifiable({...state.attemptedIds, id}),
      firstCorrectIds: Set.unmodifiable({
        ...state.firstCorrectIds,
        if (first && correct) id,
      }),
      typedFallbackIds: Set.unmodifiable({
        ...state.typedFallbackIds,
        if (modality == MotherPatternModality.typedFallback) id,
      }),
      attempts: List.unmodifiable([
        ...state.attempts,
        MotherPatternAttempt(
          exerciseId: id,
          correct: correct,
          first: first,
          hinted: state.currentHinted,
          modality: modality,
        ),
      ]),
      lastAnswerCorrect: correct,
      pendingRetry: first && !correct,
    );
    return correct;
  }

  void next() {
    if (state.finished || !state.checked) return;
    state = state._with(
      queue: List.unmodifiable([
        ...state.queue.skip(1),
        if (state.pendingRetry) state.current,
      ]),
    );
  }
}
