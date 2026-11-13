import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/pattern_lesson.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/generate_mother_pattern_course.dart' as generator;

Course loadCourse() => Course.fromJson(
  jsonDecode(
        File('assets/courses/course_mother_pattern.json').readAsStringSync(),
      )
      as Map<String, dynamic>,
);

Set<String> words(String text) => RegExp(
  r"[A-Za-z]+(?:'[A-Za-z]+)?",
).allMatches(text.toLowerCase()).map((m) => m[0]!).toSet();

void main() {
  test('new English course track resolves its independent bundled pack', () {
    final track = CourseTrack.fromId('motherPattern');
    expect(track.id, 'motherPattern');
    expect(track.assetPath, 'assets/courses/course_mother_pattern.json');
    expect(track.nextTrack, isNull);
  });

  test(
    'twelve frames and four dialogue lessons have the fixed stage counts',
    () {
      final course = loadCourse();
      var patterns = 0;
      var dialogues = 0;
      final ids = <String>{};
      for (final lesson in course.orderedLessons) {
        final metadata = lesson.patternLesson!;
        expect(lesson.id.startsWith('mp_'), isTrue);
        expect(metadata.independentExerciseIds, hasLength(4));
        expect(
          metadata.phases.map((phase) => phase.exerciseIds.length).toList(),
          metadata.kind == PatternLessonKind.pattern
              ? [2, 2, 2, 2, 2]
              : [2, 2, 2, 4],
        );
        if (metadata.kind == PatternLessonKind.pattern) {
          patterns++;
          expect(metadata.examples, hasLength(3));
          expect(metadata.review, hasLength(4));
        } else {
          dialogues++;
          expect(metadata.patternIds, hasLength(3));
        }
        for (final e in [...lesson.exercises, ...metadata.allExercises]) {
          expect(ids.add(e.id), isTrue, reason: e.id);
          expect(e.audioId, e.id);
          expect(e.accepts(e.answer), isTrue, reason: e.id);
          if (e.speakingMode == SpeakingMode.scenario ||
              e.type == ExerciseType.translateInput) {
            for (final alternative in e.acceptedAnswers) {
              expect(e.accepts(alternative), isTrue, reason: e.id);
            }
          }
        }
      }
      expect(patterns, 12);
      expect(dialogues, 4);
    },
  );

  test(
    'each lesson teaches all English words used in its tasks and dialogue',
    () {
      for (final lesson in loadCourse().orderedLessons) {
        final metadata = lesson.patternLesson!;
        final taught = metadata.vocabulary
            .map((v) => words(v.text))
            .expand((v) => v)
            .toSet();
        final spoken = [
          for (final turn in metadata.dialogue) turn.text,
          for (final e in [...lesson.exercises, ...metadata.allExercises]) ...[
            e.sentence,
            e.answer,
            ...e.acceptedAnswers,
            ...e.options,
          ],
        ].join(' ');
        expect(words(spoken).difference(taught), isEmpty, reason: lesson.id);
        for (final item in metadata.vocabulary) {
          expect(item.meaning.trim(), isNotEmpty);
          expect(item.audioId.startsWith('${lesson.id}_vocab_'), isTrue);
        }
      }
    },
  );

  test(
    'scenario tasks reject wrong role object quantity and required pattern',
    () {
      final course = loadCourse();
      final polite = course.lessonById('mp_u3l3')!.patternLesson!.review.first;
      expect(polite.accepts("I'd like a sandwich, please!"), isTrue);
      for (final wrong in [
        'I want a sandwich.',
        'I would like two sandwiches.',
        'I would like a salad.',
        'You would like a sandwich.',
      ]) {
        expect(polite.accepts(wrong), isFalse, reason: wrong);
      }
      final price = course.lessonById('mp_u4l2')!.patternLesson!.review.first;
      expect(price.accepts('How much is this book?'), isTrue);
      expect(price.accepts('How much is that book?'), isFalse);
      expect(price.accepts('How much are these books?'), isFalse);
      final fixedQuestion = course.lessonById('mp_u4l1')!.patternLesson!;
      expect(fixedQuestion.examples.map((e) => e.sentence).toSet(), {
        'What is this?',
      });
      expect(fixedQuestion.examples.map((e) => e.prompt).toSet(), hasLength(3));
    },
  );

  test(
    'rotating review tasks use four extra scenes rather than lesson prompts',
    () {
      for (final lesson in loadCourse().orderedLessons) {
        final metadata = lesson.patternLesson!;
        if (metadata.kind != PatternLessonKind.pattern) continue;
        final lessonScenes = lesson.exercises
            .skip(6)
            .map((e) => e.prompt.replaceAll('使用本课句型回答。', ''));
        expect(metadata.review.map((e) => e.prompt).toSet(), hasLength(4));
        for (final review in metadata.review) {
          for (final scene in lessonScenes) {
            expect(
              review.prompt.contains(scene),
              isFalse,
              reason: '${review.id}: $scene',
            );
          }
        }
      }
    },
  );

  test('integration listening targets occur in the taught role dialogue', () {
    for (final lesson in loadCourse().orderedLessons) {
      final metadata = lesson.patternLesson!;
      if (metadata.kind != PatternLessonKind.dialogue) continue;
      final spoken = metadata.dialogue.map((turn) => turn.text).join(' ');
      for (final exercise in lesson.exercises.take(2)) {
        expect(
          spoken.contains(exercise.sentence),
          isTrue,
          reason: '${lesson.id}: ${exercise.sentence}',
        );
      }
    }
  });

  test(
    'need dialogue hands over the requested objects with a taught support phrase',
    () {
      final metadata = loadCourse().lessonById('mp_u3l1')!.patternLesson!;
      expect(metadata.dialogue.map((turn) => turn.text).toList(), [
        'I need a pen.',
        'Here you are.',
        'I need a book, too.',
        'Here you are.',
      ]);
      final phrase = metadata.vocabulary.singleWhere(
        (item) => item.text == 'Here you are.',
      );
      expect(phrase.meaning, contains('递给'));
      expect(metadata.slotRule, contains('Here you are.'));
    },
  );

  test(
    'generator exports every exact dialogue vocabulary and exercise audio text',
    () {
      final manifest = generator.exportMotherPatternAudio(
        generator.buildMotherPatternCourse(),
      );
      final audio = manifest['audio'] as Map<String, dynamic>;
      for (final lesson in loadCourse().orderedLessons) {
        final metadata = lesson.patternLesson!;
        for (final turn in metadata.dialogue) {
          expect(audio[turn.audioId], turn.text);
        }
        for (final item in metadata.vocabulary) {
          expect(audio[item.audioId], item.text);
        }
        for (final e in [...lesson.exercises, ...metadata.allExercises]) {
          expect(audio[e.audioId], e.sentence);
        }
      }
    },
  );

  test(
    'generator rerun only reproduces the new pack without touching old packs',
    () {
      final old = <String, List<int>>{};
      for (final file in Directory(
        'assets/courses',
      ).listSync().whereType<File>()) {
        if (!file.path.endsWith('course_mother_pattern.json')) {
          old[file.path] = file.readAsBytesSync();
        }
      }
      final newPack = File(
        'assets/courses/course_mother_pattern.json',
      ).readAsBytesSync();
      final generated = generator.generateMotherPatternCourse(write: false);
      expect(
        generator.buildMotherPatternCourse(),
        jsonDecode(utf8.decode(newPack)),
      );
      expect(jsonDecode(generated), jsonDecode(utf8.decode(newPack)));
      expect(
        File('assets/courses/course_mother_pattern.json').readAsBytesSync(),
        newPack,
      );
      for (final file in old.keys) {
        expect(File(file).readAsBytesSync(), old[file], reason: file);
      }
    },
  );

  test(
    'ordinary generator write preserves editorial changes to the new pack',
    () {
      final directory = Directory.systemTemp.createTempSync(
        'mother_pattern_generator_',
      );
      try {
        final file = File('${directory.path}/course_mother_pattern.json');
        final edited = generator.buildMotherPatternCourse();
        edited['units'][0]['lessons'][0]['patternLesson']['version'] = 3;
        edited['units'][0]['lessons'][0]['patternLesson']['slotRule'] =
            '人工修订保留';
        final before = jsonEncode(edited);
        file.writeAsStringSync(before);
        IOOverrides.runZoned(
          () {
            expect(generator.generateMotherPatternCourse(write: true), before);
          },
          createFile: (path) {
            expect(path, generator.motherPatternAssetPath);
            return file;
          },
        );
        expect(file.readAsStringSync(), before);
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
  );
}
