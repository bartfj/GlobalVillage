import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_strings.dart';
import '../../app/providers.dart';
import 'feedback_screenshot.dart';

/// 侧栏「反馈问题」。说明可空，发送时附上最近诊断日志。
Future<void> showFeedbackDialog(BuildContext context, WidgetRef ref) {
  final s = ref.read(stringsProvider);
  final pick = ref.read(feedbackScreenshotPickerProvider);
  final submit = ref.read(diagnosticUploaderProvider).submitFeedback;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FeedbackDialog(s: s, pick: pick, submit: submit),
  );
}

enum _FeedbackStatus { editing, picking, submitting, sent, queued }

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({
    required this.s,
    required this.pick,
    required this.submit,
  });

  final S s;
  final Future<Uint8List?> Function() pick;
  final Future<bool> Function({required String note, Uint8List? screenshot})
  submit;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _controller = TextEditingController();
  Uint8List? _screenshot;
  String? _error;
  _FeedbackStatus _status = _FeedbackStatus.editing;

  bool get _busy =>
      _status == _FeedbackStatus.picking ||
      _status == _FeedbackStatus.submitting;

  void _start(_FeedbackStatus status) {
    FocusScope.of(context).unfocus();
    setState(() {
      _status = status;
      _error = null;
    });
  }

  Future<void> _pick() async {
    if (_busy) return;
    _start(_FeedbackStatus.picking);
    try {
      final screenshot = await widget.pick();
      if (mounted && screenshot != null) {
        setState(() => _screenshot = screenshot);
      }
    } catch (_) {
      if (mounted) setState(() => _error = widget.s.feedbackScreenshotError);
    } finally {
      if (mounted) setState(() => _status = _FeedbackStatus.editing);
    }
  }

  Future<void> _send() async {
    if (_busy) return;
    _start(_FeedbackStatus.submitting);
    try {
      final sent = await widget.submit(
        note: _controller.text,
        screenshot: _screenshot,
      );
      if (mounted) {
        setState(() {
          _status = sent ? _FeedbackStatus.sent : _FeedbackStatus.queued;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = _FeedbackStatus.editing;
          _error = widget.s.feedbackSendFailed;
        });
      }
    }
  }

  void _showScreenshot(Uint8List screenshot) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: const CloseButton(),
            title: Text(widget.s.feedbackScreenshot),
          ),
          body: SizedBox.expand(
            child: InteractiveViewer(child: Image.memory(screenshot)),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final statusTitle = switch (_status) {
      _FeedbackStatus.submitting => s.feedbackSubmitting,
      _FeedbackStatus.sent => s.feedbackSent,
      _FeedbackStatus.queued => s.feedbackUnconfirmed,
      _ => null,
    };
    if (statusTitle != null) {
      final submitting = _status == _FeedbackStatus.submitting;
      return PopScope(
        canPop: !submitting,
        child: AlertDialog(
          scrollable: true,
          shape: shape,
          title: Semantics(liveRegion: true, child: Text(statusTitle)),
          content: switch (_status) {
            _FeedbackStatus.submitting => const LinearProgressIndicator(),
            _FeedbackStatus.queued => Text(s.feedbackQueued),
            _ => null,
          },
          actions: submitting
              ? null
              : [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(s.done),
                  ),
                ],
        ),
      );
    }
    final screenshot = _screenshot;
    final error = _error;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        shape: shape,
        title: Text(s.feedbackRow),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              enabled: !_busy,
              maxLength: 500,
              maxLines: 4,
              decoration: InputDecoration(hintText: s.feedbackHint),
            ),
            if (screenshot == null)
              TextButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(s.feedbackAddScreenshot),
              )
            else ...[
              Tooltip(
                message: s.feedbackPreviewScreenshot,
                child: InkWell(
                  onTap: _busy ? null : () => _showScreenshot(screenshot),
                  child: Image.memory(
                    screenshot,
                    height: 112,
                    fit: BoxFit.contain,
                    semanticLabel: s.feedbackScreenshot,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _pick,
                    child: Text(s.feedbackReplaceScreenshot),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _screenshot = null;
                            _error = null;
                          }),
                    child: Text(s.feedbackRemoveScreenshot),
                  ),
                ],
              ),
            ],
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(s.feedbackCancel),
          ),
          TextButton(
            onPressed: _busy ? null : _send,
            child: Text(s.feedbackSend),
          ),
        ],
      ),
    );
  }
}
