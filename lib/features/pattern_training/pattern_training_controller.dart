import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/course.dart';
import '../../data/models/pattern_training.dart';

class PatternTrainingState {
  final List<Exercise> queue;
  final int totalCount;
  final bool isReview;
  final Set<String> independentIds;
  final Set<String> attemptedIds;
  final Set<String> firstCorrectIds;
  final Set<String> hintedIds;
  final bool? lastAnswerCorrect;
  final bool pendingRetry;

  const PatternTrainingState({
    required this.queue,
    required this.totalCount,
    required this.isReview,
    required this.independentIds,
    this.attemptedIds = const {},
    this.firstCorrectIds = const {},
    this.hintedIds = const {},
    this.lastAnswerCorrect,
    this.pendingRetry = false,
  });

  Exercise get current => queue.first;
  bool get checked => lastAnswerCorrect != null;
  bool get finished => queue.isEmpty;
  bool get currentHinted => !finished && hintedIds.contains(current.id);
  double get progress =>
      totalCount == 0 ? 0 : (totalCount - queue.length) / totalCount;
  int get firstCorrectCount => firstCorrectIds.length;
  int get hintedCount => hintedIds.length;
  double get accuracy => totalCount == 0 ? 0 : firstCorrectCount / totalCount;
  bool get independentSuccess =>
      finished &&
      independentIds.isNotEmpty &&
      independentIds.every(
        (id) => firstCorrectIds.contains(id) && !hintedIds.contains(id),
      );

  PatternTrainingState _with({
    List<Exercise>? queue,
    Set<String>? attemptedIds,
    Set<String>? firstCorrectIds,
    Set<String>? hintedIds,
    bool? lastAnswerCorrect,
    bool pendingRetry = false,
  }) => PatternTrainingState(
    queue: queue ?? this.queue,
    totalCount: totalCount,
    isReview: isReview,
    independentIds: independentIds,
    attemptedIds: attemptedIds ?? this.attemptedIds,
    firstCorrectIds: firstCorrectIds ?? this.firstCorrectIds,
    hintedIds: hintedIds ?? this.hintedIds,
    lastAnswerCorrect: lastAnswerCorrect,
    pendingRetry: pendingRetry,
  );
}

/// First attempts determine mastery; same-session correction only resolves the queue.
class PatternTrainingController extends StateNotifier<PatternTrainingState> {
  PatternTrainingController({
    required PatternTraining training,
    List<Exercise>? reviewExercises,
  }) : super(_initial(training, reviewExercises));

  static PatternTrainingState _initial(
    PatternTraining training,
    List<Exercise>? reviewExercises,
  ) {
    final isReview = reviewExercises?.isNotEmpty ?? false;
    final exercises = isReview ? reviewExercises! : training.exercises;
    if (isReview &&
        (exercises.length != 2 ||
            exercises.any((e) => e.type != ExerciseType.translateInput) ||
            exercises.map((e) => e.id).toSet().length != 2)) {
      throw ArgumentError(
        'A pattern review requires two distinct translateInput exercises',
      );
    }
    return PatternTrainingState(
      queue: List.unmodifiable(exercises),
      totalCount: exercises.length,
      isReview: isReview,
      independentIds: Set.unmodifiable(
        (isReview ? exercises : [...training.recall, ...training.transfer]).map(
          (e) => e.id,
        ),
      ),
    );
  }

  void revealHint() {
    if (state.finished || state.checked || state.currentHinted) return;
    state = state._with(
      hintedIds: Set.unmodifiable({...state.hintedIds, state.current.id}),
    );
  }

  bool submit(String answer) {
    if (state.finished || state.checked) {
      return state.lastAnswerCorrect ?? false;
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
      lastAnswerCorrect: correct,
      pendingRetry: first && !correct,
    );
    return correct;
  }

  void next() {
    if (state.finished || !state.checked) return;
    final queue = [...state.queue];
    final current = queue.removeAt(0);
    if (state.pendingRetry) queue.add(current);
    state = state._with(queue: List.unmodifiable(queue));
  }
}
