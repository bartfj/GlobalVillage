import 'package:flutter/material.dart';

import '../../../app/theme.dart';

enum LessonNodeStatus { completed, current, locked }

/// 学习路径上的圆形关卡节点（三态：已完成 / 可学习 / 锁定）
class LessonNode extends StatefulWidget {
  final LessonNodeStatus status;
  final String title;
  final VoidCallback onStart;

  const LessonNode({
    super.key,
    required this.status,
    required this.title,
    required this.onStart,
  });

  @override
  State<LessonNode> createState() => _LessonNodeState();
}

class _LessonNodeState extends State<LessonNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  double _shake = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.status == LessonNodeStatus.current) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _shakeLocked() async {
    for (final offset in [6.0, -6.0, 4.0, -4.0, 0.0]) {
      if (!mounted) return;
      setState(() => _shake = offset);
      await Future.delayed(const Duration(milliseconds: 40));
    }
  }

  void _onTap() {
    if (widget.status == LessonNodeStatus.locked) {
      _shakeLocked();
      return;
    }
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color shadow, IconData icon) = switch (widget.status) {
      LessonNodeStatus.completed => (
        AppColors.gold,
        AppColors.goldDark,
        Icons.check_rounded,
      ),
      LessonNodeStatus.current => (
        AppColors.green,
        AppColors.greenDark,
        Icons.star_rounded,
      ),
      LessonNodeStatus.locked => (
        AppColors.locked,
        AppColors.lockedDark,
        Icons.lock_rounded,
      ),
    };

    final node = GestureDetector(
      onTap: _onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border(bottom: BorderSide(color: shadow, width: 6)),
        ),
        child: Icon(icon, color: Colors.white, size: 34),
      ),
    );

    return Tooltip(
      message: widget.title,
      preferBelow: true,
      triggerMode: TooltipTriggerMode.tap,
      child: Transform.translate(
        offset: Offset(_shake, 0),
        child: widget.status == LessonNodeStatus.current
            ? ScaleTransition(scale: _pulse, child: node)
            : node,
      ),
    );
  }
}
