import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

/// 已通关关卡列表：可点进入重学
class CompletedLessonsPage extends ConsumerWidget {
  const CompletedLessonsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressRevisionProvider);
    final course = ref.watch(courseProvider);
    final progress = ref.watch(progressRepositoryProvider);
    final store = ref.watch(progressStoreProvider);

    if (progress == null || store == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final completed = course.orderedLessons
        .where((l) => progress.isLessonCompleted(l.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('已通关')),
      body: completed.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '还没有通关的关卡，去学习路径闯关吧',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: completed.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final lesson = completed[index];
                final record = store.get(lesson.id);
                final score = record?.score ?? 0;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  leading: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.green,
                    size: 28,
                  ),
                  title: Text(
                    lesson.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: Text(
                    '$score 分',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldDark,
                    ),
                  ),
                  onTap: () => context.push('/lesson/${lesson.id}'),
                );
              },
            ),
    );
  }
}
