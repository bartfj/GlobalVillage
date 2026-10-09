import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/services/phonetic_lookup_service.dart';
import '../../../data/models/course.dart';
import 'tappable_phonetic_text.dart';

/// 中英连线对应：点击左右两项配对，中间画贝塞尔线
class MatchPairsWidget extends StatefulWidget {
  final Exercise exercise;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const MatchPairsWidget({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<MatchPairsWidget> createState() => _MatchPairsWidgetState();
}

class _MatchPairsWidgetState extends State<MatchPairsWidget> {
  final _stackKey = GlobalKey();
  late final List<String> _left;
  late final List<String> _right;
  late final List<GlobalKey> _leftKeys;
  late final List<GlobalKey> _rightKeys;

  /// leftIndex -> rightIndex
  final Map<int, int> _links = {};
  int? _pendingLeft;
  int? _pendingRight;
  List<Offset?> _leftCenters = [];
  List<Offset?> _rightCenters = [];
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    _left = [for (final pair in widget.exercise.pairs) pair.left];
    _right = [for (final pair in widget.exercise.pairs) pair.right];
    _right.shuffle(Random(widget.exercise.id.hashCode));
    _leftKeys = List.generate(_left.length, (_) => GlobalKey());
    _rightKeys = List.generate(_right.length, (_) => GlobalKey());
    _leftCenters = List<Offset?>.filled(_left.length, null);
    _rightCenters = List<Offset?>.filled(_right.length, null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnchors());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition == position) return;
    _scrollPosition?.removeListener(_syncAnchors);
    _scrollPosition = position;
    _scrollPosition?.addListener(_syncAnchors);
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_syncAnchors);
    super.dispose();
  }

  void _syncAnchors() {
    if (!mounted) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) return;

    Offset? centerOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      return box.localToGlobal(box.size.center(Offset.zero), ancestor: stackBox);
    }

    final leftCenters = [for (final key in _leftKeys) centerOf(key)];
    final rightCenters = [for (final key in _rightKeys) centerOf(key)];
    var changed = false;
    if (leftCenters.length != _leftCenters.length) {
      changed = true;
    } else {
      for (var i = 0; i < leftCenters.length; i++) {
        if (leftCenters[i] != _leftCenters[i] ||
            rightCenters[i] != _rightCenters[i]) {
          changed = true;
          break;
        }
      }
    }
    if (!changed) return;
    setState(() {
      _leftCenters = leftCenters;
      _rightCenters = rightCenters;
    });
  }

  void _emit() {
    if (_links.length != _left.length) {
      widget.onChanged('');
      return;
    }
    widget.onChanged(
      MatchPair.encode([
        for (final entry in _links.entries)
          MatchPair(left: _left[entry.key], right: _right[entry.value]),
      ]),
    );
  }

  void _tapLeft(int index) {
    if (!widget.enabled) return;
    setState(() {
      if (_links.containsKey(index)) {
        _links.remove(index);
        _pendingLeft = null;
        _pendingRight = null;
      } else if (_pendingRight != null) {
        _links.removeWhere((_, right) => right == _pendingRight);
        _links[index] = _pendingRight!;
        _pendingLeft = null;
        _pendingRight = null;
      } else {
        _pendingLeft = index;
        _pendingRight = null;
      }
    });
    _emit();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnchors());
  }

  void _tapRight(int index) {
    if (!widget.enabled) return;
    setState(() {
      final owner = _links.entries
          .where((entry) => entry.value == index)
          .map((entry) => entry.key)
          .firstOrNull;
      if (owner != null) {
        _links.remove(owner);
        _pendingLeft = null;
        _pendingRight = null;
      } else if (_pendingLeft != null) {
        _links.removeWhere((_, right) => right == index);
        _links[_pendingLeft!] = index;
        _pendingLeft = null;
        _pendingRight = null;
      } else {
        _pendingRight = index;
        _pendingLeft = null;
      }
    });
    _emit();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnchors());
  }

  Color _lineColor(int leftIndex, int rightIndex) {
    if (widget.enabled) return AppColors.green;
    final expected = widget.exercise.pairs
        .where((pair) => pair.left == _left[leftIndex])
        .map((pair) => pair.right)
        .firstOrNull;
    return expected == _right[rightIndex] ? AppColors.green : AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnchors());
    final lines = <(Offset, Offset, Color)>[];
    for (final entry in _links.entries) {
      final from = entry.key < _leftCenters.length
          ? _leftCenters[entry.key]
          : null;
      final to = entry.value < _rightCenters.length
          ? _rightCenters[entry.value]
          : null;
      if (from == null || to == null) continue;
      lines.add((from, to, _lineColor(entry.key, entry.value)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('把中文和英文连起来', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        SizedBox(
          key: _stackKey,
          child: CustomPaint(
            painter: _MatchLinePainter(lines: lines),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < _left.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PairChip(
                            key: ValueKey('match-left:${_left[i]}'),
                            anchorKey: _leftKeys[i],
                            label: _left[i],
                            selected: _pendingLeft == i,
                            linked: _links.containsKey(i),
                            enabled: widget.enabled,
                            onTap: () => _tapLeft(i),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 36),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < _right.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PairChip(
                            key: ValueKey('match-right:${_right[i]}'),
                            anchorKey: _rightKeys[i],
                            label: _right[i],
                            selected: _pendingRight == i,
                            linked: _links.containsValue(i),
                            enabled: widget.enabled,
                            onTap: () => _tapRight(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PairChip extends StatelessWidget {
  final GlobalKey anchorKey;
  final String label;
  final bool selected;
  final bool linked;
  final bool enabled;
  final VoidCallback onTap;

  const _PairChip({
    super.key,
    required this.anchorKey,
    required this.label,
    required this.selected,
    required this.linked,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    if (selected) {
      borderColor = AppColors.blue;
    } else if (linked) {
      borderColor = AppColors.green;
    } else {
      borderColor = AppColors.locked;
    }
    final english = PhoneticLookupService.looksEnglish(label);
    final textStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: selected
          ? AppColors.blueDark
          : linked
              ? AppColors.greenDark
              : AppColors.textPrimary,
    );
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        key: anchorKey,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.blue.withValues(alpha: 0.08)
                : linked
                    ? AppColors.green.withValues(alpha: 0.08)
                    : null,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              top: BorderSide(color: borderColor, width: 2),
              left: BorderSide(color: borderColor, width: 2),
              right: BorderSide(color: borderColor, width: 2),
              bottom: BorderSide(color: borderColor, width: 4),
            ),
          ),
          child: english
              ? TappablePhoneticText(
                  label,
                  style: textStyle,
                  lookupOnLongPress: true,
                )
              : Text(label, style: textStyle),
      ),
    );
  }
}

class _MatchLinePainter extends CustomPainter {
  final List<(Offset, Offset, Color)> lines;

  _MatchLinePainter({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    for (final (from, to, color) in lines) {
      final midX = (from.dx + to.dx) / 2;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MatchLinePainter oldDelegate) {
    return oldDelegate.lines != lines;
  }
}
