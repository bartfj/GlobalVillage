import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/phonetic_lookup_service.dart';
import 'lesson_style.dart';
import 'tappable_phonetic_text.dart';

/// 底部答题判定栏：答对绿色 / 答错红色并展示正确答案；跳过为中性提示
class AnswerFeedbackBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
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
                            ? s.skippedNoCredit
                            : correct
                            ? s.correct
                            : s.reviewThis,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _AnswerLine(text: correctAnswer, color: fg),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LessonActionButton(
              label: s.continueLabel,
              onPressed: onContinue,
              error: !correct && !skipped,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  final String text;
  final Color color;

  const _AnswerLine({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: color,
    );
    if (!PhoneticLookupService.looksEnglish(text)) {
      return Text(text, style: style);
    }

    return TappablePhoneticText(text, style: style);
  }
}
