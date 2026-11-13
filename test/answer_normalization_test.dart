import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mother_pattern_schema/mother_pattern_schema.dart';

import 'mother_pattern_validation_fixture.dart';

// Literal expected values characterize the existing runtime/schema contract
// before extraction. Alternatives still require explicit authored acceptance.
const normalizedAnswers = <String, String>{
  " \tMy name’s   Tom!\n": "my name's tom",
  'I‘m Tom.': "i'm tom",
  'I´m Tom.': "i'm tom",
  'I`m Tom.': "i'm tom",
  " It is seven o’clock. ": "it is seven o'clock",
  ' [Tea] (milk)~water—bread–rice‒fruit―eggs. ':
      'tea milk water bread rice fruit eggs',
  '“Tea”，milk；water：bread！rice？fruit…eggs·juice':
      'tea milk water bread rice fruit eggs juice',
  '\tI\u00a0am\nTom.\r': 'i am tom',
  ' [!?] ': '',
};

void main() {
  for (final sample in normalizedAnswers.entries) {
    test('runtime and publication normalization agree for ${sample.key}', () {
      expect(Exercise.normalizeAnswer(sample.key), sample.value);
      expect(normalizeEnglishAnswer(sample.key), sample.value);
      final pack = independentPack();
      final task = firstLesson(pack)['exercises'][8];
      task['sentence'] = sample.key;
      task['answer'] = sample.value;
      final error = validateCourseIdentityAndPatterns(pack, 'motherPattern');
      expect(error, sample.value.isEmpty ? isNotNull : isNull);
      if (sample.value.isNotEmpty) {
        expect(Exercise.fromJson(task).accepts(sample.key), isTrue);
      }
    });
  }
  test(
    'Chinese and Sanskrit grading retain NFC case and punctuation behavior',
    () {
      const chinese = Exercise(
        id: 'zh_example',
        type: ExerciseType.translateInput,
        prompt: '中文',
        sentence: '你好。',
        options: [],
        answer: '你好。',
        language: LearningLanguage.chinese,
      );
      expect(chinese.normalizeInput(' \t你好。\n'), '你好。');
      expect(normalizeEnglishAnswer(' \t你好。\n'), '你好');
      expect(chinese.accepts('你好。'), isTrue);
      expect(chinese.accepts('你好'), isFalse);
      const sanskrit = Exercise(
        id: 'sa_example',
        type: ExerciseType.translateInput,
        prompt: '梵文',
        sentence: 'Ā.',
        options: [],
        answer: 'Ā.',
        language: LearningLanguage.sanskrit,
      );
      expect(sanskrit.normalizeInput(' A\u0304. '), 'Ā.');
      expect(normalizeEnglishAnswer(' Ā. '), 'ā');
      expect(sanskrit.accepts(' A\u0304. '), isTrue);
      expect(sanskrit.accepts('ā.'), isFalse);
      expect(sanskrit.accepts('Ā'), isFalse);
    },
  );
  test(
    'English dictation whitespace and default repeat matching are unchanged',
    () {
      const dictation = Exercise(
        id: 'old_dictation',
        type: ExerciseType.dictation,
        prompt: '听写',
        sentence: "It is seven o'clock.",
        options: [],
        answer: "It is seven o'clock.",
      );
      expect(dictation.accepts('Itisseveno’clock.'), isTrue);
      expect(dictation.accepts('It is seven\u200bo’clock.'), isTrue);
      const repeat = Exercise(
        id: 'old_repeat',
        type: ExerciseType.speaking,
        prompt: '跟读',
        sentence: 'I am Tom.',
        options: [],
        answer: 'I am Tom.',
        acceptedAnswers: ["I'm Tom."],
      );
      expect(repeat.accepts(' i AM Tom! '), isTrue);
      expect(repeat.accepts("I'm Tom."), isFalse);
    },
  );
}
