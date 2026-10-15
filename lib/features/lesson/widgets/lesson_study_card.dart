import 'package:flutter/material.dart';

import '../../../data/models/course.dart';
import '../../../data/models/learning_language.dart';

/// 课前学习卡上的一条核心内容。
class StudyItem {
  const StudyItem({this.support, required this.text, required this.meaning});

  /// 识读支架（天城体或拼音），可为空。
  final String? support;

  /// 目标语表达（IAST 或汉字）。
  final String text;

  /// 解释语含义。
  final String meaning;
}

/// 从课的题目中提取去重后的核心内容（保留出题顺序）。
List<StudyItem> lessonStudyItems(Lesson lesson) {
  final seen = <String>{};
  final items = <StudyItem>[];
  for (final e in lesson.exercises) {
    if (e.sentence.isEmpty || !seen.add(e.sentence)) continue;
    // prompt 形如“选择IAST：含义”或“Choose: meaning”。
    var sep = e.prompt.indexOf('：');
    var skip = 1;
    if (sep < 0) {
      sep = e.prompt.indexOf(': ');
      skip = 2;
    }
    items.add(
      StudyItem(
        support: e.support,
        text: e.sentence,
        meaning: sep >= 0 ? e.prompt.substring(sep + skip) : e.prompt,
      ),
    );
  }
  return items;
}

/// 新文字系统课程（中文、梵文）的课前学习卡：先看本课核心内容再开始做题。
class LessonStudyCard extends StatelessWidget {
  const LessonStudyCard({
    super.key,
    required this.lesson,
    required this.onStart,
  });

  final Lesson lesson;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final items = lessonStudyItems(lesson);
    final isSanskrit =
        lesson.exercises.first.language == LearningLanguage.sanskrit;
    final targetStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      fontFamily: isSanskrit ? 'Sanskrit' : null,
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: '返回',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '先看本课内容，再开始练习',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.support != null) ...[
                          Text(item.support!, style: targetStyle),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          item.text,
                          style: item.support == null ? targetStyle : null,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.meaning,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('开始练习'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
