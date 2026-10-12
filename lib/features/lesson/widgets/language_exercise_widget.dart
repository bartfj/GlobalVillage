import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/models/course.dart';
import '../../../data/models/learning_language.dart';

class LanguageExerciseWidget extends StatefulWidget {
  const LanguageExerciseWidget({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.checked,
    required this.answer,
    required this.onChanged,
  });
  final Exercise exercise;
  final bool enabled;
  final bool checked;
  final String answer;
  final ValueChanged<String> onChanged;

  @override
  State<LanguageExerciseWidget> createState() => _LanguageExerciseWidgetState();
}

class _LanguageExerciseWidgetState extends State<LanguageExerciseWidget> {
  final _input = TextEditingController();
  late final List<int> _bank;
  final _selected = <int>[];

  @override
  void initState() {
    super.initState();
    _bank = List.generate(widget.exercise.tokens.length, (i) => i)
      ..shuffle(Random(widget.exercise.id.hashCode));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  TextStyle get _targetStyle => TextStyle(
    fontSize: 20,
    fontFamily: widget.exercise.language == LearningLanguage.sanskrit
        ? 'Sanskrit'
        : null,
  );

  void _pick(int index, bool selected) {
    setState(() {
      if (selected) {
        _selected.remove(index);
        _bank.add(index);
      } else {
        _bank.remove(index);
        _selected.add(index);
      }
    });
    widget.onChanged(
      _selected
          .map((i) => widget.exercise.tokens[i])
          .join(widget.exercise.tokenSeparator),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ex.prompt, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        if (ex.support != null) ...[
          Text(ex.support!, style: _targetStyle),
          const SizedBox(height: 16),
        ],
        if (ex.type == ExerciseType.translateChoice)
          for (var i = 0; i < ex.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(14),
                  backgroundColor: widget.answer == ex.options[i]
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: widget.enabled
                    ? () => widget.onChanged(ex.options[i])
                    : null,
                child: Text(ex.options[i], style: _targetStyle),
              ),
            )
        else if (ex.type == ExerciseType.wordBank) ...[
          Container(
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in _selected)
                  InputChip(
                    label: Text(ex.tokens[i], style: _targetStyle),
                    onPressed: widget.enabled ? () => _pick(i, true) : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in _bank)
                ActionChip(
                  label: Text(ex.tokens[i], style: _targetStyle),
                  onPressed: widget.enabled ? () => _pick(i, false) : null,
                ),
            ],
          ),
        ] else
          TextField(
            controller: _input,
            enabled: widget.enabled,
            minLines: 1,
            maxLines: 4,
            autocorrect: false,
            enableSuggestions: false,
            style: _targetStyle,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: ex.language == LearningLanguage.chinese
                  ? '汉字 / 拼音'
                  : 'IAST / 天城体',
            ),
            onChanged: widget.onChanged,
          ),
      ],
    );
  }
}
