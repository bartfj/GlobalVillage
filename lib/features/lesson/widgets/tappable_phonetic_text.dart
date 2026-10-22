import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/services/phonetic_lookup_service.dart';

const ipaFontFamily = 'NotoSans';

/// 查询中 / 无音标 / 外包 LTR isolate，避免 IPA 在中文环境下被反向。
String formatIpaLabel(String? ipa, {required bool loading}) {
  if (loading) {
    return '查询中…';
  }
  final t = ipa?.trim();
  if (t == null || t.isEmpty) {
    return '暂无音标，可点喇叭';
  }
  return '\u2066$t\u2069';
}

OverlayEntry? _activePhoneticOverlay;

/// 关闭当前音标气泡（切题时调用）
void dismissPhoneticBubble() {
  _activePhoneticOverlay?.remove();
  _activePhoneticOverlay = null;
}

/// 在锚点附近展示单词音标气泡
void showPhoneticBubble(
  BuildContext context, {
  required String word,
  required Offset globalPosition,
  Size? anchorSize,
}) {
  dismissPhoneticBubble();
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _PhoneticBubbleOverlay(
      word: word,
      globalPosition: globalPosition,
      anchorSize: anchorSize ?? Size.zero,
      onDismiss: () {
        entry.remove();
        if (_activePhoneticOverlay == entry) {
          _activePhoneticOverlay = null;
        }
      },
    ),
  );
  _activePhoneticOverlay = entry;
  overlay.insert(entry);
}

/// 从 [RenderBox] 锚点弹出
void showPhoneticBubbleForBox(BuildContext context, String word, RenderBox box) {
  final offset = box.localToGlobal(Offset.zero);
  showPhoneticBubble(
    context,
    word: word,
    globalPosition: offset,
    anchorSize: box.size,
  );
}

/// 英文句子按词可点查音标
class TappablePhoneticText extends ConsumerWidget {
  const TappablePhoneticText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.lookupOnLongPress = false,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// 为 true 时点按交给外层（如连线卡片），长按才查该词音标。
  final bool lookupOnLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final parts = text.split(RegExp(r'(\s+)'));
    return Wrap(
      alignment: _wrapAlign(textAlign),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final part in parts)
          if (part.trim().isEmpty)
            Text(part, style: baseStyle)
          else if (PhoneticLookupService.looksEnglish(part))
            _TappableWord(
              word: part,
              style: baseStyle,
              lookupOnLongPress: lookupOnLongPress,
            )
          else
            Text(part, style: baseStyle),
      ],
    );
  }

  WrapAlignment _wrapAlign(TextAlign? align) {
    switch (align) {
      case TextAlign.center:
        return WrapAlignment.center;
      case TextAlign.right:
      case TextAlign.end:
        return WrapAlignment.end;
      default:
        return WrapAlignment.start;
    }
  }
}

class _TappableWord extends StatelessWidget {
  const _TappableWord({
    required this.word,
    required this.style,
    this.lookupOnLongPress = false,
  });

  final String word;
  final TextStyle style;
  final bool lookupOnLongPress;

  void _show(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    showPhoneticBubbleForBox(context, word, box);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: lookupOnLongPress ? null : () => _show(context),
      onLongPress: lookupOnLongPress ? () => _show(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0x8C1CB0F6),
              width: 1,
            ),
          ),
        ),
        child: Text(
          word,
          style: style.copyWith(
            decoration: TextDecoration.none,
            color: style.color ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PhoneticBubbleOverlay extends ConsumerStatefulWidget {
  const _PhoneticBubbleOverlay({
    required this.word,
    required this.globalPosition,
    required this.anchorSize,
    required this.onDismiss,
  });

  final String word;
  final Offset globalPosition;
  final Size anchorSize;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_PhoneticBubbleOverlay> createState() =>
      _PhoneticBubbleOverlayState();
}

class _PhoneticBubbleOverlayState extends ConsumerState<_PhoneticBubbleOverlay> {
  bool _loading = true;
  PhoneticResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ref
        .read(phoneticLookupProvider)
        .lookup(widget.word);
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  Future<void> _speak() async {
    final tts = ref.read(ttsServiceProvider);
    final display = PhoneticLookupService.normalize(widget.word);
    final word = display.isEmpty ? widget.word.trim() : display;
    if (word.isEmpty) return;
    // 有道发音在国内可达；失败则 speakUrlOrText 内回退系统 TTS
    final voiceUrl =
        'https://dict.youdao.com/dictvoice?type=2&audio=${Uri.encodeQueryComponent(word)}';
    await tts.speakUrlOrText(
      _result?.audioUrl?.trim().isNotEmpty == true
          ? _result!.audioUrl
          : voiceUrl,
      word,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    const bubbleMaxWidth = 240.0;
    final left = (widget.globalPosition.dx)
        .clamp(8.0, media.width - bubbleMaxWidth - 8);
    var top = widget.globalPosition.dy - 56;
    if (top < padding.top + 8) {
      top = widget.globalPosition.dy + widget.anchorSize.height + 6;
    }

    final ipaLabel = formatIpaLabel(_result?.ipa, loading: _loading);
    final meaning = _result?.meaning?.trim();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: const ColoredBox(color: Color(0x00000000)),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            // 吸收点击，避免穿透到背后遮罩导致气泡被立刻关掉、发音中断
            child: GestureDetector(
              onTap: () {},
              child: Container(
                constraints: const BoxConstraints(maxWidth: bubbleMaxWidth),
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.locked, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            PhoneticLookupService.normalize(widget.word).isEmpty
                                ? widget.word
                                : PhoneticLookupService.normalize(widget.word),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ipaLabel,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontFamily: ipaFontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _loading
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (meaning != null && meaning.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 6),
                              child: Text(
                                meaning,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.25,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '朗读',
                      onPressed: () {
                        _speak();
                      },
                      icon: const Icon(
                        Icons.volume_up_rounded,
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
