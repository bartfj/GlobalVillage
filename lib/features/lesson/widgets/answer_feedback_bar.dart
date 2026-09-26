import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// 底部答题判定栏：答对绿色 / 答错红色并展示正确答案
class AnswerFeedbackBar extends StatelessWidget {
  final bool correct;
  final String correctAnswer;
  final VoidCallback onContinue;

  const AnswerFeedbackBar({
    super.key,
    required this.correct,
    required this.correctAnswer,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final bg = correct ? AppColors.greenLight : AppColors.redLight;
    final fg = correct ? AppColors.greenDark : AppColors.redDark;
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
                  correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: fg,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        correct ? '太棒了！' : '正确答案：',
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
              color: correct ? AppColors.green : AppColors.red,
              shadowColor: correct ? AppColors.greenDark : AppColors.redDark,
            ),
          ],
        ),
      ),
    );
  }
}
