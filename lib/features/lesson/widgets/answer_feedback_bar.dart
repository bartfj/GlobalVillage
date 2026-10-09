import 'package:flutter/material.dart';

import 'lesson_style.dart';

/// 底部答题判定栏：答对绿色 / 答错红色并展示正确答案；跳过为中性提示
class AnswerFeedbackBar extends StatelessWidget {
  final bool correct;
  final bool skipped;
  final String correctAnswer;
  final VoidCallback onContinue;

  const AnswerFeedbackBar({
    super.key,
    required this.correct,
    required this.correctAnswer,
    required this.onContinue,
    this.skipped = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (skipped) {
      bg = LessonColors.track;
      fg = LessonColors.muted;
    } else if (correct) {
      bg = LessonColors.greenLight;
      fg = LessonColors.greenDark;
    } else {
      bg = LessonColors.redLight;
      fg = LessonColors.redDark;
    }

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fg.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    skipped
                        ? Icons.skip_next_rounded
                        : correct
                        ? Icons.check_rounded
                        : Icons.close_rounded,
                    color: fg,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skipped
                            ? '已跳过（不计分）'
                            : correct
                            ? '回答正确！'
                            : '再记一下这句话',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        correctAnswer,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LessonActionButton(
              label: '继续',
              onPressed: onContinue,
              error: !correct && !skipped,
            ),
          ],
        ),
      ),
    );
  }
}
