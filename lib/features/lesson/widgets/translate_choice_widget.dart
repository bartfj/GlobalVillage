import 'package:flutter/material.dart';

import '../../../core/services/phonetic_lookup_service.dart';
import '../../../data/models/course.dart';
import 'lesson_style.dart';
import 'tappable_phonetic_text.dart';

/// 翻译单选题：题干 + 4 个选项卡
class TranslateChoiceWidget extends StatelessWidget {
  final Exercise exercise;
  final bool enabled;
  final String? selected;
  final bool checked;
  final ValueChanged<String> onChanged;

  const TranslateChoiceWidget({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.selected,
    required this.onChanged,
    this.checked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: LessonColors.greenLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.translate_rounded,
                size: 18,
                color: LessonColors.greenDark,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '翻译练习',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: LessonColors.greenDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '选择正确的翻译',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: LessonColors.ink,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.only(left: 16, bottom: 16),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF66B999), width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                PhoneticLookupService.looksEnglish(exercise.prompt)
                    ? '英文 → 中文'
                    : '中文 → 英文',
                style: const TextStyle(fontSize: 12, color: LessonColors.muted),
              ),
              const SizedBox(height: 9),
              PhoneticLookupService.looksEnglish(exercise.prompt)
                  ? TappablePhoneticText(
                      exercise.prompt,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: LessonColors.ink,
                      ),
                    )
                  : Text(
                      exercise.prompt,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: LessonColors.ink,
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < exercise.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionCard(
              label: exercise.options[i],
              letter: String.fromCharCode(65 + i),
              selected: selected == exercise.options[i],
              correct: checked && exercise.options[i] == exercise.answer,
              wrong:
                  checked &&
                  selected == exercise.options[i] &&
                  exercise.options[i] != exercise.answer,
              enabled: enabled,
              onTap: () => onChanged(exercise.options[i]),
            ),
          ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final String letter;
  final bool correct;
  final bool wrong;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.letter,
    required this.correct,
    required this.wrong,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected || correct || wrong;
    final borderColor = correct
        ? LessonColors.green
        : wrong
        ? LessonColors.red
        : selected
        ? LessonColors.blue
        : LessonColors.border;
    final foreground = correct
        ? LessonColors.greenDark
        : wrong
        ? LessonColors.redDark
        : selected
        ? LessonColors.blueDark
        : LessonColors.ink;
    final background = correct
        ? LessonColors.greenLight
        : wrong
        ? LessonColors.redLight
        : selected
        ? LessonColors.blueLight
        : Colors.white;
    final english = PhoneticLookupService.looksEnglish(label);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              top: BorderSide(color: borderColor, width: 1.5),
              left: BorderSide(color: borderColor, width: 1.5),
              right: BorderSide(color: borderColor, width: 1.5),
              bottom: BorderSide(color: borderColor, width: 3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? borderColor.withValues(alpha: 0.12)
                      : const Color(0xFFF7F9F8),
                  border: Border.all(
                    color: active
                        ? borderColor.withValues(alpha: 0.3)
                        : LessonColors.border,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? foreground : LessonColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: english
                    ? TappablePhoneticText(
                        label,
                        lookupOnLongPress: enabled,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? borderColor : Colors.transparent,
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: active
                    ? Icon(
                        wrong ? Icons.close_rounded : Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
