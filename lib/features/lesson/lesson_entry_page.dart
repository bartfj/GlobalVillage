import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../data/models/course_track.dart';
import '../mother_pattern/mother_pattern_page.dart';
import 'lesson_page.dart';

/// Course identity controls entry; cached pilot metadata cannot switch flows.
class LessonEntryPage extends ConsumerWidget {
  const LessonEntryPage({
    super.key,
    required this.lessonId,
    this.initialExerciseIndex = 0,
    this.bypassUnlock = false,
  });
  final String lessonId;
  final int initialExerciseIndex;
  final bool bypassUnlock;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(selectedTrackProvider) == CourseTrack.motherPattern
      ? MotherPatternPage(lessonId: lessonId)
      : LessonPage(
          lessonId: lessonId,
          initialExerciseIndex: initialExerciseIndex,
          bypassUnlock: bypassUnlock,
        );
}
