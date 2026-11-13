import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/course.dart';
import '../../data/models/skill_practice.dart';

/// 构造调试用课程跳转路径：`/lesson/:id?debug=1&ex=N`
String debugLessonLocation(String lessonId, {int exerciseIndex = 0}) {
  final params = <String, String>{'debug': '1'};
  if (exerciseIndex > 0) {
    params['ex'] = '$exerciseIndex';
  }
  return Uri(path: '/lesson/$lessonId', queryParameters: params).toString();
}

/// 解析 `/lesson/:id` 上的调试查询参数。
({int exerciseIndex, bool bypassUnlock}) parseLessonDebugQuery(
  Map<String, String> query,
) {
  final raw = int.tryParse(query['ex'] ?? '') ?? 0;
  return (
    exerciseIndex: raw < 0 ? 0 : raw,
    bypassUnlock: query['debug'] == '1',
  );
}

/// 课内第一道跟读题的下标；没有则返回 null。
int? firstSpeakingIndex(Lesson lesson) {
  for (var i = 0; i < lesson.exercises.length; i++) {
    if (lesson.exercises[i].type == ExerciseType.speaking) return i;
  }
  return null;
}

/// 开发后门菜单：跳过关卡 / 跳到指定课题 / 跳到专项章。
Future<void> showDebugJumpMenu(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback onSkipCurrentLesson,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('调试后门'),
      children: [
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(dialogContext);
            onSkipCurrentLesson();
          },
          child: const Text('跳过当前关卡'),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(dialogContext);
            showDebugLessonJumpDialog(context, ref);
          },
          child: const Text('跳到指定课 / 题'),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(dialogContext);
            showDebugPracticeJumpDialog(context, ref);
          },
          child: const Text('跳到专项练习章'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    ),
  );
}

/// 输入课 ID + 题索引（从 0），直接进答题页（绕过解锁）。
Future<void> showDebugLessonJumpDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final course = ref.read(courseProvider);
  final current = ref.read(progressRepositoryProvider)?.currentLesson;
  final fallbackId =
      course.orderedLessons.isEmpty ? '' : course.orderedLessons.first.id;
  final lessonController = TextEditingController(
    text: current?.id ?? fallbackId,
  );
  final indexController = TextEditingController(text: '0');
  String? error;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('跳到指定课 / 题'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '当前课程：${course.title}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lessonController,
                decoration: const InputDecoration(
                  labelText: '课 ID',
                  hintText: '例如 u1l1 / z_u1l1',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: indexController,
                decoration: const InputDecoration(
                  labelText: '题索引（从 0 起）',
                  hintText: '英语跟读多在 8',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    final lesson = course.lessonById(
                      lessonController.text.trim(),
                    );
                    if (lesson == null) {
                      setState(() => error = '课 ID 不存在');
                      return;
                    }
                    final speaking = firstSpeakingIndex(lesson);
                    if (speaking == null) {
                      setState(() => error = '该课没有跟读题');
                      return;
                    }
                    setState(() {
                      indexController.text = '$speaking';
                      error = null;
                    });
                  },
                  child: const Text('填入本课第一道跟读'),
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(color: AppColors.red, fontSize: 13),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final lessonId = lessonController.text.trim();
              final lesson = course.lessonById(lessonId);
              if (lesson == null) {
                setState(() => error = '课 ID 不存在');
                return;
              }
              final index = int.tryParse(indexController.text.trim());
              if (index == null || index < 0) {
                setState(() => error = '题索引须为非负整数');
                return;
              }
              if (index >= lesson.exercises.length) {
                setState(
                  () => error =
                      '题索引超出范围（本课共 ${lesson.exercises.length} 题）',
                );
                return;
              }
              Navigator.pop(dialogContext);
              context.push(
                debugLessonLocation(lessonId, exerciseIndex: index),
              );
            },
            child: const Text('开始', style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    ),
  );

  lessonController.dispose();
  indexController.dispose();
}

/// 输入专项 skill + 章 ID，直接进专项会话（绕过章节地图解锁）。
Future<void> showDebugPracticeJumpDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final language = ref.read(selectedTrackProvider).language;
  final skills = SkillPracticeKind.forLanguage(language);
  if (skills.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前语言没有专项练习')));
    return;
  }

  var skill = skills.contains(SkillPracticeKind.speaking)
      ? SkillPracticeKind.speaking
      : skills.first;
  final chapterController = TextEditingController(
    text: skill == SkillPracticeKind.speaking ? 'spk-early' : '',
  );
  String? error;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('跳到专项练习章'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('专项', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              for (final item in skills)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.title),
                  trailing: item == skill
                      ? const Icon(Icons.check, color: AppColors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      skill = item;
                      if (item == SkillPracticeKind.speaking &&
                          chapterController.text.trim().isEmpty) {
                        chapterController.text = 'spk-early';
                      }
                    });
                  },
                ),
              const SizedBox(height: 8),
              TextField(
                controller: chapterController,
                decoration: const InputDecoration(
                  labelText: '章 ID',
                  hintText: '例如 spk-early',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: const TextStyle(color: AppColors.red, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final chapterId = chapterController.text.trim();
              if (chapterId.isEmpty) {
                setState(() => error = '请填写章 ID');
                return;
              }
              Navigator.pop(dialogContext);
              context.push('/practice/${skill.name}/$chapterId');
            },
            child: const Text('开始', style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    ),
  );

  chapterController.dispose();
}
