import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/features/lesson/sanskrit_answer_display.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise _ex({
  required String prompt,
  required String sentence,
  required String answer,
  String? support,
  ExerciseType type = ExerciseType.translateChoice,
  LearningLanguage language = LearningLanguage.sanskrit,
}) {
  return Exercise(
    id: 't1',
    type: type,
    prompt: prompt,
    sentence: sentence,
    options: const [],
    answer: answer,
    language: language,
    support: support,
  );
}

void main() {
  test('yoga reading shows Devanagari, IAST and Chinese', () {
    final text = formatCorrectAnswerForDisplay(
      _ex(
        prompt: '选择 IAST：合十礼',
        sentence: 'namaste',
        answer: 'namaste',
        support: 'नमस्ते',
      ),
    );
    expect(text, 'नमस्ते · namaste · 合十礼');
  });

  test('yoga meaning shows Devanagari, IAST and Chinese', () {
    final text = formatCorrectAnswerForDisplay(
      _ex(
        prompt: '“namaste” 是什么意思？',
        sentence: '合十礼',
        answer: '合十礼',
        support: 'नमस्ते',
      ),
    );
    expect(text, 'नमस्ते · namaste · 合十礼');
  });

  test('letter item without Chinese keeps Devanagari and IAST', () {
    final text = formatCorrectAnswerForDisplay(
      _ex(
        prompt: '选择 IAST：क',
        sentence: 'ka',
        answer: 'ka',
        support: 'क',
      ),
    );
    expect(text, 'क · ka');
  });

  test('non-Sanskrit leaves answer unchanged', () {
    final text = formatCorrectAnswerForDisplay(
      _ex(
        prompt: 'Choose the translation',
        sentence: 'hello',
        answer: 'hello',
        language: LearningLanguage.english,
      ),
    );
    expect(text, 'hello');
  });

  test('matchPairs keeps pair display format', () {
    final text = formatCorrectAnswerForDisplay(
      _ex(
        prompt: 'Match',
        sentence: '',
        answer: 'क=ka|ख=kha',
        type: ExerciseType.matchPairs,
      ),
    );
    expect(text, 'क — ka\nख — kha');
  });
}
