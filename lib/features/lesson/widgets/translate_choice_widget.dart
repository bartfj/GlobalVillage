import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/course.dart';

/// 翻译单选题：题干 + 4 个选项卡
class TranslateChoiceWidget extends StatelessWidget {
  final Exercise exercise;
  final bool enabled;
  final String? selected;
  final ValueChanged<String> onChanged;

  const TranslateChoiceWidget({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('选择正确的翻译', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.locked, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            exercise.prompt,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 16),
        for (final option in exercise.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionCard(
              label: option,
              selected: selected == option,
              enabled: enabled,
              onTap: () => onChanged(option),
            ),
          ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.blue : AppColors.locked;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            top: BorderSide(color: borderColor, width: 2),
            left: BorderSide(color: borderColor, width: 2),
            right: BorderSide(color: borderColor, width: 2),
            bottom: BorderSide(color: borderColor, width: 4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.blueDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
