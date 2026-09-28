import 'package:flutter/material.dart';

import '../../../app/theme.dart';

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
    final Color buttonColor;
    final Color shadowColor;
    if (skipped) {
      bg = AppColors.locked;
      fg = AppColors.lockedDark;
      buttonColor = AppColors.blue;
      shadowColor = AppColors.blueDark;
    } else if (correct) {
      bg = AppColors.greenLight;
      fg = AppColors.greenDark;
      buttonColor = AppColors.green;
      shadowColor = AppColors.greenDark;
    } else {
      bg = AppColors.redLight;
      fg = AppColors.redDark;
      buttonColor = AppColors.red;
      shadowColor = AppColors.redDark;
    }

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  skipped
                      ? Icons.skip_next_rounded
                      : correct
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                  color: fg,
                  size: 28,
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
                                ? '太棒了！'
                                : '正确答案：',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                      if (!correct)
                        Text(
                          correctAnswer,
                          style: TextStyle(
                            fontSize: 15,
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
            PushableButton(
              label: '继续',
              onPressed: onContinue,
              color: buttonColor,
              shadowColor: shadowColor,
            ),
          ],
        ),
      ),
    );
  }
}
