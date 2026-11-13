import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:english_village/data/models/course.dart';

import '../tool/generate_pattern_pilot.dart';
import '../tool/expand_learning_tracks.dart' as expansion;

void main() {
  test('course expansion rerun retains all pilot editorial metadata', () {
    final before =
        jsonDecode(
              File('assets/courses/course_beginner.json').readAsStringSync(),
            )
            as Map;
    final generated =
        jsonDecode(
              expansion.generateExpansion(
                write: false,
              )['assets/courses/course_beginner.json']!,
            )
            as Map;
    final patterns = {
      for (final u in before['units'])
        for (final l in u['lessons'])
          if (l['patternTraining'] != null) l['id']: l['patternTraining'],
    };
    for (final u in generated['units']) {
      for (final l in u['lessons']) {
        if (patterns.containsKey(l['id'])) {
          expect(l['patternTraining'], patterns[l['id']]);
        }
      }
    }
  });
  test('real pilot answer variants enforce frame, item and quantity', () {
    final course = Course.fromJson(
      jsonDecode(File('assets/courses/course_beginner.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final polite = course.lessonById('u4l4')!.patternTraining!.recall.first;
    final name = course.lessonById('u1l2')!.patternTraining!.recall.first;
    expect(name.accepts("My name’s Tom."), isTrue);
    expect(name.accepts("My name’s Amy."), isFalse);
    expect(polite.accepts("I’d like a sandwich, please!"), isTrue);
    expect(polite.accepts('I want a sandwich.'), isFalse);
    expect(polite.accepts('I would like two sandwiches.'), isFalse);
    expect(polite.accepts('I would like a salad.'), isFalse);
    final price = course.lessonById('u9l1')!.patternTraining!.recall.first;
    expect(price.accepts('how much is this book'), isTrue);
    expect(price.accepts('How much is that book?'), isFalse);
    expect(price.accepts('How much are these books?'), isFalse);
    for (final lesson in course.orderedLessons.where(
      (l) => l.patternTraining != null,
    )) {
      for (final e in lesson.patternTraining!.allExercises) {
        final file = File('assets/audio/listening/${e.id}.mp3');
        expect(file.existsSync(), isTrue, reason: e.id);
        expect(file.lengthSync(), greaterThan(256), reason: e.id);
        expect(e.accepts(e.answer), isTrue, reason: e.id);
        for (final a in e.acceptedAnswers) {
          expect(e.accepts(a), isTrue, reason: e.id);
        }
      }
    }
  });
  test(
    'generator preserves scored content and later editorial revisions on rerun',
    () {
      final course =
          jsonDecode(
                File('assets/courses/course_beginner.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final before = jsonEncode(course);
      final result = withPatternPilot(course);
      expect(jsonEncode(course), before);
      expect(result, course);
      final lesson = result['units'][0]['lessons'][1];
      lesson['patternTraining']['version'] = 2;
      lesson['patternTraining']['slotRule'] = '人工修订';
      final revised = withPatternPilot(result);
      expect(
        revised['units'][0]['lessons'][1]['patternTraining']['slotRule'],
        '人工修订',
      );
      expect(
        revised['units'][0]['lessons'][1]['patternTraining']['version'],
        2,
      );
    },
  );
  test('pilot uses vocabulary introduced by its source lesson', () {
    final course =
        jsonDecode(
              File('assets/courses/course_beginner.json').readAsStringSync(),
            )
            as Map;
    final known = <String>{};
    Set<String> words(String text) => RegExp(
      r"[A-Za-z]+(?:'[A-Za-z]+)?",
    ).allMatches(text.toLowerCase()).map((m) => m[0]!).toSet();
    for (final unit in course['units']) {
      for (final lesson in unit['lessons']) {
        for (final e in lesson['exercises']) {
          known.addAll(words(e['sentence'] as String));
          for (final pair in (e['pairs'] as List? ?? [])) {
            known.addAll(words(pair['right'] as String));
          }
        }
        final p = lesson['patternTraining'] as Map?;
        if (p == null) continue;
        for (final phase in [
          'examples',
          'substitution',
          'recall',
          'transfer',
          'review',
        ]) {
          for (final e in p[phase]) {
            expect(
              words(e['sentence'] as String).difference(known),
              isEmpty,
              reason: '${lesson['id']} ${e['id']}',
            );
          }
        }
      }
    }
  });
  test(
    'six existing lessons teach frames without replacing scored questions',
    () {
      final course =
          jsonDecode(
                File('assets/courses/course_beginner.json').readAsStringSync(),
              )
              as Map;
      final expected = {
        'u1l2': 'My name is …',
        'u4l1': 'I like …',
        'u4l3': 'I want …',
        'u4l4': 'I would like …',
        'u9l1': 'How much is …?',
        'u9l2': 'I need …',
      };
      final seen = <String>{};
      final ids = <String>{};
      for (final unit in course['units']) {
        for (final lesson in unit['lessons']) {
          final exercises = lesson['exercises'] as List;
          expect(exercises.length, 9, reason: lesson['id']);
          for (var i = 0; i < exercises.length; i++) {
            expect(exercises[i]['id'], '${lesson['id']}e${i + 1}');
          }
          final pattern = lesson['patternTraining'] as Map?;
          if (!expected.containsKey(lesson['id'])) {
            expect(pattern, isNull);
            continue;
          }
          expect(
            pattern,
            isNotNull,
            reason: '${lesson['id']} needs frame training',
          );
          final p = pattern!;
          seen.add(lesson['id'] as String);
          expect(p['frame'], expected[lesson['id']]);
          expect((p['examples'] as List).length, 3);
          for (final phase in [
            'substitution',
            'recall',
            'transfer',
            'review',
          ]) {
            final items = p[phase] as List;
            expect(items.length, phase == 'review' ? 4 : 2);
            for (final item in items) {
              expect(ids.add(item['id'] as String), isTrue);
              expect(
                item['type'],
                phase == 'substitution' ? 'wordBank' : 'translateInput',
              );
              if (phase == 'substitution') {
                expect((item['tokens'] as List).join(' '), item['answer']);
              }
            }
          }
        }
      }
      expect(seen, expected.keys.toSet());
    },
  );
}
