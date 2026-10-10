import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/course.dart';
import '../lesson/dialogue_practice.dart';
import '../lesson/lesson_page.dart';

class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  bool _busy = false;
  String _statsMode = 'lesson';

  Future<void> _practice(
    String title,
    List<Exercise> exercises,
    String mode,
  ) async {
    if (exercises.isEmpty || _busy) return;
    setState(() => _busy = true);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LessonPage(
          lessonId: 'practice',
          mode: mode,
          practiceLesson: Lesson(
            id: 'practice-$mode',
            title: title,
            exercises: exercises,
          ),
        ),
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _dialogue(Unit unit) async {
    try {
      final exercises = await buildDialoguePractice(unit);
      if (!mounted) return;
      await _practice('${unit.title} · 对话应用', exercises, 'dialogue');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('对话加载失败，请重试。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(courseProvider);
    final progress = ref.watch(progressRepositoryProvider);
    final store = ref.watch(learningStoreProvider);
    if (progress == null || store == null) return const Scaffold();
    final unlocked = course.orderedLessons
        .where((l) => progress.isLessonUnlocked(l.id))
        .map((l) => l.id)
        .toSet();
    final due = store.dueExercises(course, unlocked);
    final completedUnits = course.units
        .where((u) => u.lessons.every((l) => progress.isLessonCompleted(l.id)))
        .toList();
    final events = store.events
        .where(
          (e) =>
              e['courseId'] == course.id &&
              e['mode'] == _statsMode &&
              e['kind'] == 'answer' &&
              e['skipped'] != true,
        )
        .toList();
    final sessions = store.events
        .where((e) => e['courseId'] == course.id && e['mode'] == _statsMode)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('复习与学习记录'),
        actions: [
          IconButton(
            tooltip: '导出学习记录',
            icon: const Icon(Icons.download_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: store.exportJson()));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('学习记录已复制。')));
              }
            },
          ),
          IconButton(
            tooltip: '清除复习与学习记录',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final clear = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('清除学习记录？'),
                  content: const Text('错题复习与统计将被清除，课程成绩和奖励不受影响。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('清除'),
                    ),
                  ],
                ),
              );
              if (clear == true) {
                await store.clear();
                if (mounted) setState(() {});
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(course.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_rounded),
            title: const Text('今日错题'),
            subtitle: Text('${due.length} 题待复习'),
            trailing: const Icon(Icons.chevron_right),
            onTap: due.isEmpty || _busy
                ? null
                : () => _practice('错题复习', due, 'review'),
          ),
          const Divider(),
          const Text(
            '单元复习',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (completedUnits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('暂无已完成单元'),
            ),
          for (final unit in completedUnits)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(unit.title),
              subtitle: const Text('综合练习与对话应用'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '单元复习',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _busy
                        ? null
                        : () => _practice('${unit.title} · 复习', [
                            for (final l in unit.lessons) ...[
                              l.exercises[4],
                              l.exercises[6],
                            ],
                          ], 'unit'),
                  ),
                  IconButton(
                    tooltip: '对话应用',
                    icon: const Icon(Icons.forum_outlined),
                    onPressed: _busy ? null : () => _dialogue(unit),
                  ),
                ],
              ),
            ),
          const Divider(),
          const Text(
            '题型表现',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'lesson', label: Text('课程')),
              ButtonSegment(value: 'review', label: Text('错题')),
              ButtonSegment(value: 'unit', label: Text('单元')),
              ButtonSegment(value: 'dialogue', label: Text('对话')),
            ],
            selected: {_statsMode},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                setState(() => _statsMode = value.first),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '开始 ${sessions.where((e) => e['kind'] == 'start').length} 次 · '
              '完成 ${sessions.where((e) => e['kind'] == 'finish').length} 次 · '
              '退出 ${sessions.where((e) => e['kind'] == 'exit').length} 次',
            ),
          ),
          for (final type in ExerciseType.values)
            if (events.any((e) => e['type'] == type.name && e['first'] == true))
              Builder(
                builder: (_) {
                  final samples = events
                      .where(
                        (e) => e['type'] == type.name && e['first'] == true,
                      )
                      .toList();
                  final correct = samples
                      .where((e) => e['correct'] == true)
                      .length;
                  final time = samples.fold<int>(
                    0,
                    (sum, e) => sum + (e['elapsedMs'] as int),
                  );
                  const labels = [
                    '翻译选择',
                    '词块组句',
                    '听力选择',
                    '单词填空',
                    '跟读',
                    '中英连线',
                    '听音组句',
                    '整句听写',
                    '输入翻译',
                  ];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(labels[type.index]),
                    subtitle: Text(
                      '${samples.length} 次首次作答 · 平均 ${(time / samples.length / 1000).round()} 秒',
                    ),
                    trailing: Text(
                      '${(correct / samples.length * 100).round()}%',
                    ),
                  );
                },
              ),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('暂无作答记录'),
            ),
        ],
      ),
    );
  }
}
