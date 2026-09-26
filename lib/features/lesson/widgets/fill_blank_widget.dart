import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/course.dart';

/// 拼写填空题：补全句子中缺失的单词
class FillBlankWidget extends StatefulWidget {
  final Exercise exercise;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const FillBlankWidget({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<FillBlankWidget> createState() => _FillBlankWidgetState();
}

class _FillBlankWidgetState extends State<FillBlankWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blankSentence =
        widget.exercise.sentenceWithBlank ?? widget.exercise.sentence;
    final parts = blankSentence.split('____');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('补全句子', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.locked, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.exercise.prompt,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (parts.isNotEmpty)
                    Text(parts.first, style: _sentenceStyle(context)),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _controller,
                      enabled: widget.enabled,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blueDark,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '输入单词',
                        hintStyle: TextStyle(
                          color: AppColors.lockedDark,
                          fontWeight: FontWeight.w400,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.blue,
                            width: 2,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.blueDark,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: widget.onChanged,
                    ),
                  ),
                  if (parts.length > 1)
                    Text(parts.sublist(1).join('____'), style: _sentenceStyle(context)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle? _sentenceStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;
}
