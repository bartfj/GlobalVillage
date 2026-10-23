import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/learning_language.dart';

/// 用系统 TTS 朗读英文文本的喇叭按钮；失败时提示，不阻塞答题。
class EnglishTtsButton extends ConsumerStatefulWidget {
  const EnglishTtsButton({super.key, required this.text});

  final String text;

  @override
  ConsumerState<EnglishTtsButton> createState() => _EnglishTtsButtonState();
}

class _EnglishTtsButtonState extends ConsumerState<EnglishTtsButton> {
  bool _playing = false;

  Future<void> _play() async {
    setState(() => _playing = true);
    bool ok;
    try {
      ok = await ref.read(ttsServiceProvider).speak(widget.text);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _playing = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref
                .read(stringsProvider)
                .audioPlaybackFailed(LearningLanguage.english),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: ref.read(stringsProvider).playPronunciation,
      visualDensity: VisualDensity.compact,
      onPressed: _playing ? null : _play,
      icon: _playing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.volume_up_rounded),
    );
  }
}
