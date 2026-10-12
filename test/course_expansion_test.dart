import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/sources/course_loader.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/expand_learning_tracks.dart' as expansion;
import '../tool/validate_course_content.dart' as validation;

class CompletedTrackStore implements ProgressStore {
  final Set<String> completed;
  CompletedTrackStore(this.completed);

  @override
  LessonProgress? get(String lessonId) => completed.contains(lessonId)
      ? LessonProgress(
          lessonId: lessonId,
          completed: true,
          score: 1,
          correctCount: 9,
          totalCount: 9,
          completedAt: DateTime(2026),
        )
      : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'three tracks load with globally unique IDs and intermediate choices',
    () async {
      final courses = await CourseLoader().loadAll();
      expect(courses.map((c) => c.id), [
        'zero',
        'beginner',
        'intermediate',
        'chinese',
        'sanskrit',
      ]);
      expect(courses.map((c) => c.orderedLessons.length), [
        232,
        272,
        64,
        16,
        16,
      ]);
      final ids = <String>{};
      for (final course in courses) {
        for (final unit in course.units) {
          expect(ids.add(unit.id), isTrue);
          for (final lesson in unit.lessons) {
            expect(ids.add(lesson.id), isTrue);
            for (final ex in lesson.exercises) {
              expect(ids.add(ex.id), isTrue);
            }
          }
        }
      }
      expect(CourseTrack.fromId('intermediate'), CourseTrack.intermediate);
      expect(CourseTrack.fromId('elementary'), CourseTrack.beginner);
      expect(CourseTrack.fromId('unknown'), CourseTrack.beginner);
      final intermediate = courses[2];
      expect(intermediate.title, '英语中级');
      expect(intermediate.units, hasLength(16));
      for (final lesson in intermediate.orderedLessons) {
        expect(lesson.exercises, hasLength(9));
      }
      validation.main();
    },
  );

  test('previously completed tracks resume at first appended lesson', () {
    for (final entry in {
      'zero': 168,
      'beginner': 208,
      'intermediate': 0,
    }.entries) {
      final course = Course.fromJson(
        jsonDecode(
              File(
                'assets/courses/course_${entry.key}.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      final completed = course.orderedLessons
          .take(entry.value)
          .map((l) => l.id)
          .toSet();
      final progress = ProgressRepository(
        store: CompletedTrackStore(completed),
        course: course,
      );
      expect(progress.currentLesson?.id, course.orderedLessons[entry.value].id);
      expect(
        progress.isLessonUnlocked(course.orderedLessons[entry.value + 1].id),
        isFalse,
      );
      expect(
        progress.isLessonCompleted(course.orderedLessons.first.id),
        entry.value > 0,
      );
    }
  });

  test(
    'authored expansion is deterministic and preserves the original units',
    () {
      final paths = [
        for (final track in CourseTrack.values.where(
          (t) => t.id != 'chinese' && t.id != 'sanskrit',
        ))
          track.assetPath,
        'assets/dialogues/unit_dialogues.json',
        'assets/dialogues/application_tasks.json',
        'docs/新增192课教学台账.md',
        'docs/本轮扩课目录.md',
      ];
      final before = {
        for (final path in paths) path: File(path).readAsStringSync(),
      };
      final generated = expansion.generateExpansion(write: false);
      for (final path in paths) {
        expect(generated[path], before[path], reason: path);
      }
    },
  );
}
