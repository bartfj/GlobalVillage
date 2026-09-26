import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../data/models/course.dart';

/// 词块排序组句题：点击乱序词块拼出正确句子
class WordBankWidget extends StatefulWidget {
  final Exercise exercise;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const WordBankWidget({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<WordBankWidget> createState() => _WordBankWidgetState();
}

class _WordBankWidgetState extends State<WordBankWidget> {
  late final List<String> _bank;
  final List<String> _selected = [];
  int? _dragIndex;

  @override
  void initState() {
    super.initState();
    // 固定种子洗牌：同一题重渲染时顺序稳定
    final words = widget.exercise.sentence.split(' ');
    words.shuffle(Random(widget.exercise.id.hashCode));
    _bank = words;
  }

  void _pick(int index) {
    if (!widget.enabled) return;
    setState(() => _selected.add(_bank.removeAt(index)));
    widget.onChanged(_selected.join(' '));
  }

  void _unpick(int index) {
    if (!widget.enabled) return;
    setState(() => _bank.add(_selected.removeAt(index)));
    widget.onChanged(_selected.join(' '));
  }

  /// 一次拖放可能被嵌套的内外 DragTarget 同时接收，用 _dragIndex 消费标记去重
  void _consumeDrop(int from, int to) {
    if (!widget.enabled || _dragIndex != from) return;
    setState(() => _dragIndex = null);
    setState(() {
      final item = _selected.removeAt(from);
      _selected.insert(to.clamp(0, _selected.length), item);
    });
    widget.onChanged(_selected.join(' '));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('把词块排成句子', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.locked, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            widget.exercise.prompt,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 16),
        // 答题区：长按词块可拖动调整顺序，点击则移回词库
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.locked.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.locked, width: 2),
          ),
          // 拖到空白处 = 移到末尾
          child: DragTarget<int>(
            onWillAcceptWithDetails: (details) =>
                widget.enabled && _dragIndex != null,
            onAcceptWithDetails: (details) =>
                _consumeDrop(details.data, _selected.length),
            builder: (context, candidate, rejected) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _selected.length; i++)
                  _DraggableChip(
                    key: ValueKey('sel_$i'),
                    index: i,
                    label: _selected[i],
                    enabled: widget.enabled,
                    dragging: _dragIndex == i,
                    onTap: () => _unpick(i),
                    onDragStarted: () {
                      HapticFeedback.mediumImpact();
                      setState(() => _dragIndex = i);
                    },
                    onDragEnded: () => setState(() => _dragIndex = null),
                    onDroppedOn: (from) => _consumeDrop(from, i),
                  ),
              ],
            ),
          ),
        ),
        if (_selected.length > 1)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '长按词块可拖动调整顺序，拖动开始时词块变绿并震动提示',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        const SizedBox(height: 20),
        // 词块库
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _bank.length; i++)
              _WordChip(label: _bank[i], onTap: () => _pick(i)),
          ],
        ),
      ],
    );
  }
}

/// 已选词块：点击移回词库，长按拖动可调整顺序
class _DraggableChip extends StatelessWidget {
  final int index;
  final String label;
  final bool enabled;
  final bool dragging;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final ValueChanged<int> onDroppedOn;

  const _DraggableChip({
    super.key,
    required this.index,
    required this.label,
    required this.enabled,
    required this.dragging,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onDroppedOn,
  });

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<int>(
      data: index,
      // 默认 500ms 偏长，缩短长按激活时间让拖动更跟手
      delay: const Duration(milliseconds: 150),
      maxSimultaneousDrags: enabled ? null : 0,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnded(),
      onDragCompleted: onDragEnded,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.1,
          child: _WordChip(label: label, onTap: () {}, elevated: true, dragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _WordChip(label: label, onTap: () {}),
      ),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) => onDroppedOn(details.data),
        builder: (context, candidate, rejected) => _WordChip(
          label: label,
          onTap: onTap,
          dragging: dragging,
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool dragging;
  final bool elevated;

  const _WordChip({
    required this.label,
    required this.onTap,
    this.dragging = false,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = dragging ? AppColors.green : AppColors.locked;
    final shadowColor = dragging ? AppColors.greenDark : AppColors.lockedDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: dragging ? AppColors.greenLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          // 底部硬阴影模拟 3D 按压边（非均匀色 border + 圆角在 debug 下会断言崩溃）
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: Offset(0, elevated ? 5 : 3),
              blurRadius: elevated ? 8 : 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
