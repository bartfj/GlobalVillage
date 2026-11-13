import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:english_village/app/app_strings.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_controller.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_question.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_speech.dart';
import 'mother_pattern_speech_test.dart'
    show FakePatternRecorder, FakePatternRecognizer;

void main() {
  final course = Course.fromJson(
    jsonDecode(
      File('assets/courses/course_mother_pattern.json').readAsStringSync(),
    ),
  );
  for (final language in UiLanguage.values) {
    for (final scene in ['fixed recall', 'fixed review', 'mixed dialogue']) {
      testWidgets(
        '$scene hint hides canonical alternative and teaching examples in ${language.name}',
        (tester) async {
          final lesson = course.lessonById(
            scene == 'mixed dialogue' ? 'mp_u4l4' : 'mp_u4l1',
          )!;
          final pattern = lesson.patternLesson!;
          final controller = MotherPatternController(
            lesson: lesson,
            reviewExercises: scene == 'fixed review'
                ? pattern.review.take(2).toList()
                : null,
          );
          if (scene != 'fixed review') {
            for (var i = 0; i < 6; i++) {
              final e = controller.state.current;
              controller.submit(
                e.answer,
                modality: e.type == ExerciseType.speaking
                    ? MotherPatternModality.spoken
                    : MotherPatternModality.typed,
              );
              controller.next();
            }
          }
          final e = controller.state.current;
          final input = TextEditingController();
          final speech = MotherPatternSpeech(
            recorder: FakePatternRecorder(),
            recognizer: FakePatternRecognizer(),
          );
          addTearDown(controller.dispose);
          addTearDown(input.dispose);
          addTearDown(speech.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (context, setState) => MotherPatternQuestion(
                      state: controller.state,
                      pattern: pattern,
                      speech: speech,
                      strings: S(language),
                      input: input,
                      answer: '',
                      onAnswer: (_) {},
                      onHint: () {
                        controller.revealHint();
                        setState(() {});
                      },
                      onFallback: () {},
                      onCheck: () {},
                      onNext: () {},
                      onRecord: () {},
                      onPlay: (_) async {},
                    ),
                  ),
                ),
              ),
            ),
          );
          tester
              .widget<MotherPatternQuestion>(find.byType(MotherPatternQuestion))
              .onHint();
          await tester.pump();
          final visible = tester
              .widgetList<Text>(find.byType(Text))
              .map((w) => w.data ?? '')
              .join('\n');
          for (final answer in [e.answer, ...e.acceptedAnswers]) {
            expect(
              visible.contains(answer),
              false,
              reason: 'Complete target exposed: $answer',
            );
          }
          expect(find.text(pattern.slotRule), findsNothing);
          expect(visible.contains('This is a book.'), false);
          expect(find.byKey(const ValueKey('reference-audio')), findsNothing);
          expect(controller.state.hintedCount, 1);
        },
      );
    }
  }
}
