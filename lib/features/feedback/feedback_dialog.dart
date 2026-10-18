import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

/// 侧栏「反馈问题」。说明可空，发送时附上最近诊断日志。
Future<void> showFeedbackDialog(BuildContext context, WidgetRef ref) async {
  final note = await showDialog<String>(
    context: context,
    builder: (dialogContext) => const _FeedbackDialog(),
  );
  if (note == null || !context.mounted) return;

  final sent = await ref.read(diagnosticUploaderProvider).submitNote(note);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(sent ? '已发送' : '已保存在手机上，联网后会自动发送')));
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('反馈问题'),
      content: TextField(
        controller: _controller,
        maxLength: 500,
        maxLines: 4,
        decoration: const InputDecoration(hintText: '发生了什么（可以不填）'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            '取消',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('发送', style: TextStyle(color: AppColors.green)),
        ),
      ],
    );
  }
}
