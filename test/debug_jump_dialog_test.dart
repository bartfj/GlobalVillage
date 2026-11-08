import 'package:english_village/data/models/course.dart';
import 'package:english_village/features/learning_path/debug_jump_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise _ex(String id, ExerciseType type) => Exercise(
      id: id,
      type: type,
      prompt: 'p',
      sentence: 's',
      options: const [],
      answer: 'a',
    );

void main() {
  test('debugLessonLocation 带 debug 与题索引', () {
    expect(
      debugLessonLocation('u1l1', exerciseIndex: 8),
      '/lesson/u1l1?debug=1&ex=8',
    );
    expect(debugLessonLocation('u1l1'), '/lesson/u1l1?debug=1');
  });

  test('parseLessonDebugQuery 解析 ex 与 debug', () {
    final parsed = parseLessonDebugQuery({'debug': '1', 'ex': '8'});
    expect(parsed.bypassUnlock, isTrue);
    expect(parsed.exerciseIndex, 8);

    final normal = parseLessonDebugQuery(const {});
    expect(normal.bypassUnlock, isFalse);
    expect(normal.exerciseIndex, 0);

    expect(parseLessonDebugQuery({'ex': '-3'}).exerciseIndex, 0);
  });

  test('firstSpeakingIndex 返回第一道跟读下标', () {
    final lesson = Lesson(
      id: 'u1l1',
      title: 't',
      exercises: [
        _ex('e1', ExerciseType.translateChoice),
        _ex('e2', ExerciseType.wordBank),
        _ex('e9', ExerciseType.speaking),
        _ex('e10', ExerciseType.speaking),
      ],
    );
    expect(firstSpeakingIndex(lesson), 2);
  });

  test('firstSpeakingIndex 无跟读时返回 null', () {
    final lesson = Lesson(
      id: 'u1l1',
      title: 't',
      exercises: [_ex('e1', ExerciseType.translateChoice)],
    );
    expect(firstSpeakingIndex(lesson), isNull);
  });
}
