import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/course.dart';
import '../../../data/models/learning_language.dart';

class LanguageExerciseWidget extends ConsumerStatefulWidget {
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
  ConsumerState<LanguageExerciseWidget> createState() =>
      _LanguageExerciseWidgetState();
}

class _LanguageExerciseWidgetState
    extends ConsumerState<LanguageExerciseWidget> {
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

  /// 普通键盘打不出的字符，点按插入光标处。
  static const _sanskritChars = [
    'ā', 'ī', 'ū', 'ṛ', 'ṅ', 'ñ', 'ṭ', 'ḍ', 'ṇ', 'ś', 'ṣ', 'ṃ', 'ḥ',
  ];
  static const _chineseChars = [
    'ā', 'á', 'ǎ', 'à', 'ē', 'é', 'ě', 'è',
    'ī', 'í', 'ǐ', 'ì', 'ō', 'ó', 'ǒ', 'ò',
    'ū', 'ú', 'ǔ', 'ù', 'ǖ', 'ǘ', 'ǚ', 'ǜ',
  ];

  List<String> get _specialChars =>
      widget.exercise.language == LearningLanguage.sanskrit
          ? _sanskritChars
          : _chineseChars;

  void _insertChar(String char) {
    final text = _input.text;
    final selection = _input.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final next = text.replaceRange(start, end, char);
    _input.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + char.length),
    );
    widget.onChanged(next);
  }

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
    final s = ref.watch(stringsProvider);
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
        ] else ...[
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
                  ? s.scriptLabelsHanzi
                  : s.scriptLabelsIast,
              helperText: ex.language == LearningLanguage.chinese
                  ? s.pinyinKeyboardHint
                  : s.iastKeyboardHint,
            ),
            onChanged: widget.onChanged,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final char in _specialChars)
                ActionChip(
                  label: Text(char),
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      widget.enabled ? () => _insertChar(char) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
