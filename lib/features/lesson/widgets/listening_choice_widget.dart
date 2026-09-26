import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../data/models/course.dart';

/// 听力选择题：TTS 播放英文句子，选择正确的中文意思
class ListeningChoiceWidget extends ConsumerStatefulWidget {
  final Exercise exercise;
  final bool enabled;
  final String? selected;
  final ValueChanged<String> onChanged;

  const ListeningChoiceWidget({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.selected,
    required this.onChanged,
  });

  @override
  ConsumerState<ListeningChoiceWidget> createState() =>
      _ListeningChoiceWidgetState();
}

class _ListeningChoiceWidgetState extends ConsumerState<ListeningChoiceWidget> {
  @override
  void initState() {
    super.initState();
    // 进入题目自动播放一遍
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  void _speak() {
    ref.read(ttsServiceProvider).speakExercise(widget.exercise);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.exercise.prompt,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _speak,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(24),
                border: const Border(
                  bottom: BorderSide(color: AppColors.blueDark, width: 5),
                ),
              ),
              child: const Icon(
                Icons.volume_up_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        for (final option in widget.exercise.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ListenOptionCard(
              label: option,
              selected: widget.selected == option,
              enabled: widget.enabled,
              onTap: () => widget.onChanged(option),
            ),
          ),
      ],
    );
  }
}

class _ListenOptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ListenOptionCard({
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
