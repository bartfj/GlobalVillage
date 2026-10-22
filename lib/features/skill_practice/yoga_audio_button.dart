import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/services/sanskrit_audio_service.dart';
import '../../data/models/learning_language.dart';
import '../../data/models/yoga_term_audio.dart';
import 'yoga_audio_providers.dart';

/// 瑜伽术语的参考发音按钮；音频按条目 id 从内置资源校验后播放。
class YogaAudioButton extends ConsumerStatefulWidget {
  const YogaAudioButton({super.key, required this.audioId});

  final String audioId;

  @override
  ConsumerState<YogaAudioButton> createState() => _YogaAudioButtonState();
}

class _YogaAudioButtonState extends ConsumerState<YogaAudioButton> {
  bool _playing = false;

  Future<void> _play(YogaTermAudio term) async {
    setState(() => _playing = true);
    SanskritPlaybackResult result;
    try {
      result = await ref.read(yogaAudioServiceProvider).play(term);
    } catch (_) {
      result = SanskritPlaybackResult.failed;
    }
    if (!mounted) return;
    setState(() => _playing = false);
    if (result == SanskritPlaybackResult.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref
                .read(stringsProvider)
                .audioPlaybackFailed(LearningLanguage.sanskrit),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 自动销毁的播放资源要跟着按钮一起存活，否则点按后会被立刻释放。
    ref.watch(yogaAudioServiceProvider);
    final term = ref
        .watch(yogaTermAudioCatalogProvider)
        .maybeWhen(
          data: (catalog) => catalog.terms[widget.audioId],
          orElse: () => null,
        );
    if (term == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: ref.read(stringsProvider).playPronunciation,
      visualDensity: VisualDensity.compact,
      onPressed: _playing ? null : () => _play(term),
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
