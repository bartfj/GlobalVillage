import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_strings.dart';
import '../../app/providers.dart';
import '../../data/models/course.dart';
import '../../data/models/pattern_lesson.dart';
import '../../data/sources/mother_pattern_store.dart';
import 'mother_pattern_page.dart';
import 'mother_pattern_providers.dart';

class MotherPatternReviewPage extends ConsumerStatefulWidget {
  const MotherPatternReviewPage({super.key});
  @override
  ConsumerState<MotherPatternReviewPage> createState() =>
      _MotherPatternReviewPageState();
}

class _MotherPatternReviewPageState
    extends ConsumerState<MotherPatternReviewPage> {
  bool _busy = false;
  Future<void> _open(Lesson lesson, {bool refresher = false}) async {
    if (_busy) return;
    final store = ref.read(motherPatternStoreProvider);
    final course = ref.read(courseProvider);
    if (store == null) return;
    final snapshot = refresher ? null : store.reviewSnapshot(course.id, lesson);
    setState(() => _busy = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MotherPatternPage(
          lessonId: lesson.id,
          lesson: lesson,
          practice: refresher,
          reviewSnapshot: snapshot,
        ),
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  String _summary(S s, MotherPatternSessionSummary summary) {
    final reason = switch (summary.saveReason) {
      MotherPatternSaveReason.learning => s.motherPatternLearningContext,
      MotherPatternSaveReason.dueReview => s.motherPatternDueContext,
      MotherPatternSaveReason.practice => s.motherPatternPracticeContext,
      MotherPatternSaveReason.staleReview => s.motherPatternStaleContext,
      MotherPatternSaveReason.dialogue => s.motherPatternDialogueContext,
    };
    return [
      reason,
      s.motherPatternIndependent(
        summary.independentCorrect,
        summary.independentTotal,
      ),
      s.motherPatternSpoken(summary.independentSpokenCorrect),
      s.motherPatternTyped(summary.independentTypedCorrect),
      s.motherPatternFallback(summary.independentTypedFallbackCorrect),
      s.patternHints(summary.hints),
      if (summary.fallbackUsed) s.motherPatternFallbackUsed,
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final course = ref.watch(courseProvider);
    final store = ref.watch(motherPatternStoreProvider);
    final learning = ref.watch(learningStoreProvider);
    final progress = ref.watch(progressRepositoryProvider);
    ref.watch(progressRevisionProvider);
    if (store == null || progress == null) return const Scaffold();
    final due = store.dueLessons(course);
    final learned = course.orderedLessons
        .where(
          (lesson) =>
              lesson.patternLesson != null &&
              (store
                          .latestSummary(course.id, lesson.patternLesson!)
                          ?.saveReason ==
                      MotherPatternSaveReason.learning ||
                  store
                          .latestSummary(course.id, lesson.patternLesson!)
                          ?.saveReason ==
                      MotherPatternSaveReason.dialogue ||
                  store.reviewEntry(course.id, lesson.patternLesson!) != null ||
                  progress.isLessonCompleted(lesson.id)),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(s.reviewRecords),
        actions: [
          IconButton(
            tooltip: s.isEn ? 'Export records' : '导出学习记录',
            icon: const Icon(Icons.download_rounded),
            onPressed: learning == null
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: learning.exportJson()),
                    );
                  },
          ),
          IconButton(
            tooltip: s.isEn ? 'Clear learning records' : '清除学习记录',
            icon: const Icon(Icons.delete_outline),
            onPressed: learning == null
                ? null
                : () async {
                    final clear = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          s.isEn ? 'Clear learning records?' : '清除学习记录？',
                        ),
                        content: Text(s.clearLearningRecordsBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(s.back),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(s.isEn ? 'Clear' : '清除'),
                          ),
                        ],
                      ),
                    );
                    if (clear == true) {
                      await learning.clear();
                      if (mounted) setState(() {});
                    }
                  },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.motherPatternTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Text(
              s.patternToday,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (due.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(s.patternNoDue),
              ),
            for (final lesson in due)
              ListTile(
                key: ValueKey('review-due-${lesson.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(lesson.patternLesson!.frame),
                subtitle: Text(
                  s.patternNextReview(
                    store.reviewEntry(course.id, lesson.patternLesson!)!.due,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _open(lesson),
              ),
            const Divider(height: 32),
            Text(
              s.motherPatternLearned,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (learned.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(s.motherPatternNoLearned),
              ),
            for (final lesson in learned)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        lesson.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        store.latestSummary(course.id, lesson.patternLesson!) ==
                                null
                            ? s.motherPatternNoRecord
                            : _summary(
                                s,
                                store.latestSummary(
                                  course.id,
                                  lesson.patternLesson!,
                                )!,
                              ),
                      ),
                      if (store.reviewEntry(course.id, lesson.patternLesson!) !=
                          null)
                        Text(
                          s.patternNextReview(
                            store
                                .reviewEntry(course.id, lesson.patternLesson!)!
                                .due,
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (lesson.patternLesson!.kind ==
                          PatternLessonKind.pattern)
                        OutlinedButton(
                          key: ValueKey('review-practice-${lesson.id}'),
                          onPressed: _busy ? null : () => _open(lesson),
                          child: Text(s.motherPatternReview),
                        ),
                      TextButton(
                        key: ValueKey('refresher-${lesson.id}'),
                        onPressed: _busy
                            ? null
                            : () => _open(lesson, refresher: true),
                        child: Text(s.motherPatternRefresher),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
