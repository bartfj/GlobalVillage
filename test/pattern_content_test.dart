import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_pattern_pilot.dart';
import '../tool/expand_learning_tracks.dart' as expansion;

Map<String, dynamic> legacyBaseline() {
  final result = Process.runSync('git', [
    'show',
    'd691041:assets/courses/course_beginner.json',
  ], stdoutEncoding: utf8);
  expect(result.exitCode, 0);
  return jsonDecode(result.stdout as String) as Map<String, dynamic>;
}

Map<String, dynamic> currentBeginner() =>
    jsonDecode(File('assets/courses/course_beginner.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('withdrawal removes only the six injected fields from baseline', () {
    final original = legacyBaseline();
    final removed = <String>[];
    for (final unit in original['units']) {
      for (final lesson in unit['lessons']) {
        if (lesson.remove('patternTraining') != null) {
          removed.add(lesson['id'] as String);
        }
      }
    }
    expect(removed, ['u1l2', 'u4l1', 'u4l3', 'u4l4', 'u9l1', 'u9l2']);
    expect(currentBeginner(), original);
  });
  test('retired generator cannot reinject withdrawn pilot content', () {
    final course = currentBeginner();
    final before = jsonEncode(course);
    for (final refresh in [false, true]) {
      final result = withPatternPilot(course, refresh: refresh);
      expect(result, course);
      expect(jsonEncode(course), before);
      expect(
        Course.fromJson(
          result,
        ).orderedLessons.where((l) => l.patternTraining != null),
        isEmpty,
      );
    }
  });
  test(
    'legacy generator API preserves unrelated unknown editorial metadata',
    () {
      final course = currentBeginner();
      course['units'][0]['lessons'][0]['editorial'] = {'revision': 4};
      final result = withPatternPilot(course);
      result['units'][0]['lessons'][0]['editorial']['revision'] = 5;
      expect(course['units'][0]['lessons'][0]['editorial']['revision'], 4);
    },
  );
  test('ordinary expansion rerun retains withdrawal', () {
    final generated =
        jsonDecode(
              expansion.generateExpansion(
                write: false,
              )['assets/courses/course_beginner.json']!,
            )
            as Map<String, dynamic>;
    expect(
      Course.fromJson(
        generated,
      ).orderedLessons.where((l) => l.patternTraining != null),
      isEmpty,
    );
  });
  test('withdrawn legacy JSON and audio remain backwards compatible', () {
    final course = Course.fromJson(legacyBaseline());
    final legacy = course.orderedLessons
        .where((l) => l.patternTraining != null)
        .toList();
    expect(legacy, hasLength(6));
    for (final lesson in legacy) {
      expect(lesson.patternLesson, isNull);
      for (final exercise in lesson.patternTraining!.allExercises) {
        expect(exercise.accepts(exercise.answer), isTrue);
        final clip = File('assets/audio/listening/${exercise.id}.mp3');
        expect(clip.existsSync(), isTrue);
        expect(clip.lengthSync(), greaterThan(256));
      }
    }
    final polite = course.lessonById('u4l4')!.patternTraining!.recall.first;
    expect(polite.accepts("I’d like a sandwich, please!"), isTrue);
    expect(polite.accepts('I want a sandwich.'), isFalse);
    expect(polite.accepts('I would like two sandwiches.'), isFalse);
  });
}
