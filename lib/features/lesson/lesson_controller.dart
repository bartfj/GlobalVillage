import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/course.dart';

const Object _unset = Object();

/// 答题流程状态
class LessonState {
  /// 剩余题目队列，队首为当前题；首次答错的题会被移到队尾重做
  final List<Exercise> queue;

  /// 初始题数
  final int totalCount;

  /// 首次尝试即答对的题数（用于正确率）
  final int correctCount;

  /// 已答错过的题 id（同一题第二次答错则直接跳过，不再重排）
  final Set<String> wrongOnce;

  /// 当前题判定结果：null=未提交，true/false=已判定
  final bool? lastAnswerCorrect;

  /// 当前题在"继续"后是否需要移到队尾重做
  final bool pendingRetry;

  /// 降级跳过（如跟读完成）：已判定但不计正确、不重做
  final bool skipped;

  const LessonState({
    required this.queue,
    required this.totalCount,
    required this.correctCount,
    required this.wrongOnce,
    required this.lastAnswerCorrect,
    required this.pendingRetry,
    this.skipped = false,
  });

  factory LessonState.initial(Lesson lesson) => LessonState(
        queue: List.of(lesson.exercises),
        totalCount: lesson.exercises.length,
        correctCount: 0,
        wrongOnce: const {},
        lastAnswerCorrect: null,
        pendingRetry: false,
      );

  Exercise get current => queue.first;
  bool get checked => lastAnswerCorrect != null;
  bool get finished => queue.isEmpty;

  /// 进度条：已完成题数 / 总题数
  double get progress =>
      totalCount == 0 ? 0 : (totalCount - queue.length) / totalCount;

  double get accuracy => totalCount == 0 ? 0 : correctCount / totalCount;

  LessonState copyWith({
    List<Exercise>? queue,
    int? correctCount,
    Set<String>? wrongOnce,
    Object? lastAnswerCorrect = _unset,
    bool? pendingRetry,
    bool? skipped,
  }) {
    return LessonState(
      queue: queue ?? this.queue,
      totalCount: totalCount,
      correctCount: correctCount ?? this.correctCount,
      wrongOnce: wrongOnce ?? this.wrongOnce,
      lastAnswerCorrect: lastAnswerCorrect == _unset
          ? this.lastAnswerCorrect
          : lastAnswerCorrect as bool?,
      pendingRetry: pendingRetry ?? this.pendingRetry,
      skipped: skipped ?? this.skipped,
    );
  }
}

/// 答题流程状态机
class LessonController extends StateNotifier<LessonState> {
  LessonController(Lesson lesson) : super(LessonState.initial(lesson));

  /// 提交答案，返回是否正确。答案做归一化比较（大小写/空格/句尾标点不敏感）。
  bool submit(String answer) {
    if (state.checked || state.finished) {
      return state.lastAnswerCorrect ?? false;
    }
    final correct = _normalize(answer) == _normalize(state.current.answer);
    final isRetry = state.wrongOnce.contains(state.current.id);
    final wrongOnce = {...state.wrongOnce};
    var correctCount = state.correctCount;
    if (correct) {
      if (!isRetry) correctCount++;
    } else {
      wrongOnce.add(state.current.id);
    }
    state = state.copyWith(
      correctCount: correctCount,
      wrongOnce: wrongOnce,
      lastAnswerCorrect: correct,
      pendingRetry: !correct && !isRetry,
      skipped: false,
    );
    return correct;
  }

  /// 降级跳过：出队前进，不计正确分、不入重做队列。
  void skipWithoutCredit() {
    if (state.checked || state.finished) return;
    state = state.copyWith(
      lastAnswerCorrect: false,
      pendingRetry: false,
      skipped: true,
    );
  }

  /// 进入下一题：答对或二次答错则出队；首次答错移到队尾重做
  void next() {
    if (!state.checked) return;
    final queue = [...state.queue];
    final current = queue.removeAt(0);
    if (state.pendingRetry) queue.add(current);
    state = state.copyWith(
      queue: queue,
      lastAnswerCorrect: null,
      pendingRetry: false,
      skipped: false,
    );
  }

  static String _normalize(String text) {
    var s = text.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceAll(RegExp(r'[.!?,;]+$'), '');
    return s;
  }
}

final lessonControllerProvider = StateNotifierProvider.autoDispose
    .family<LessonController, LessonState, Lesson>(
      (ref, lesson) => LessonController(lesson),
    );
