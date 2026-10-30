import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../app/theme.dart';
import '../../../core/services/diagnostic_log.dart';
import '../../../core/services/tts_service.dart';
import '../../../data/sources/content_documents.dart';
import '../dialogue_script.dart';

class DialoguePerformance extends StatefulWidget {
  final String unitId;
  final String unitTitle;
  final ContentDocuments? documents;
  final VoidCallback onFinished;

  const DialoguePerformance({
    super.key,
    required this.unitId,
    required this.unitTitle,
    this.documents,
    required this.onFinished,
  });

  @override
  State<DialoguePerformance> createState() => _DialoguePerformanceState();
}

class _DialoguePerformanceState extends State<DialoguePerformance> {
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<void>? _completeSub;
  DialogueScript? _script;
  Timer? _timer;
  int _index = 0;
  int _generation = 0;
  bool _finished = false;

  /// 仅在本句真正开始播放后为 true，避免 stop() 误触发 completed 切句。
  bool _awaitingComplete = false;

  @override
  void initState() {
    super.initState();
    _completeSub = _player.onPlayerComplete.listen((_) {
      _onPlaybackComplete();
    });
    _tts.setCompletionHandler(() {
      _onPlaybackComplete();
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final script = await DialogueScript.load(
        widget.unitId,
        documents: widget.documents,
      );
      if (!mounted || _finished) return;
      if (script == null) {
        _finish();
        return;
      }
      setState(() => _script = script);
      _playLine();
    } catch (_) {
      if (mounted) _finish();
    }
  }

  void _playLine() {
    final script = _script;
    if (script == null || _finished) return;
    final line = script.lines[_index];
    final generation = ++_generation;
    _awaitingComplete = false;
    final words = line.english.split(RegExp(r'\s+')).length;
    // 兜底：部分机型不回调 completed 时仍能推进。
    final timeout = Duration(
      milliseconds: (words * 400 + 2000).clamp(4500, 12000),
    );
    _timer?.cancel();
    _timer = Timer(timeout, () => _advance(generation: generation));
    unawaited(_playVoice(line, _index + 1, generation));
  }

  Future<void> _playVoice(
    DialogueLine line,
    int lineNumber,
    int generation,
  ) async {
    final relative = 'audio/dialogues/${widget.unitId}_$lineNumber.mp3';
    try {
      // stop 可能触发 completed；此时 _awaitingComplete 仍为 false，会被忽略。
      await _player.stop();
      await _tts.stop();
      if (!mounted || _finished || generation != _generation) return;
      final cached = await widget.documents?.audioFilePath(relative);
      // 缺文件时不要先 play：失败的播放会占着音频焦点，随后的系统 TTS 会无声。
      if (cached == null && !await _bundleHasAudio(relative)) {
        await _speakLine(line, generation);
        return;
      }
      await _player.play(
        cached == null ? AssetSource(relative) : DeviceFileSource(cached),
      );
      if (!mounted || _finished || generation != _generation) return;
      _awaitingComplete = true;
    } catch (error, stack) {
      recordDiagnosticError('dialogue-audio', error, stack);
      if (!mounted || _finished || generation != _generation) return;
      await _speakLine(line, generation);
    }
  }

  Future<bool> _bundleHasAudio(String relative) async {
    try {
      await rootBundle.load('assets/$relative');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 没有内置录音时用系统英语朗读。先放开播放器焦点，并确认引擎真的开读。
  Future<void> _speakLine(DialogueLine line, int generation) async {
    try {
      await _player.stop();
      if (!mounted || _finished || generation != _generation) return;
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      if (!mounted || _finished || generation != _generation) return;
      var result = await _tts.speak(line.english);
      if (!TtsService.speakResultOk(result)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted || _finished || generation != _generation) return;
        await _tts.stop();
        result = await _tts.speak(line.english);
      }
      if (!TtsService.speakResultOk(result)) {
        recordDiagnosticError(
          'dialogue-audio',
          'TTS did not start: ${line.english}',
        );
        return;
      }
      _awaitingComplete = true;
    } catch (error, stack) {
      recordDiagnosticError('dialogue-audio', error, stack);
    }
  }

  void _onPlaybackComplete() {
    if (!_awaitingComplete || _finished) return;
    final generation = _generation;
    _awaitingComplete = false;
    _advance(generation: generation);
  }

  void _advance({required int generation}) {
    if (!mounted || _finished || generation != _generation) return;
    _awaitingComplete = false;
    _timer?.cancel();
    final script = _script;
    if (script == null) return;

    if (_index + 1 >= script.lines.length) {
      _timer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted || _finished || generation != _generation) return;
        _finish();
      });
      return;
    }

    _timer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _finished || generation != _generation) return;
      setState(() => _index++);
      _playLine();
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _awaitingComplete = false;
    _generation++;
    _timer?.cancel();
    unawaited(_player.stop());
    unawaited(_tts.stop());
    widget.onFinished();
  }

  @override
  void dispose() {
    _finished = true;
    _awaitingComplete = false;
    _generation++;
    _timer?.cancel();
    unawaited(_completeSub?.cancel());
    unawaited(_player.dispose());
    unawaited(_tts.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final script = _script;
    final line = script?.lines[_index];
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: const Color(0xFFF6F9F5),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.unitTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(onPressed: _finish, child: const Text('跳过')),
                ],
              ),
            ),
            if (script != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < script.lines.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: i <= _index
                                  ? AppColors.green
                                  : AppColors.locked,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(
                      0,
                      MediaQuery.sizeOf(context).height -
                          MediaQuery.paddingOf(context).vertical -
                          175,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Character(
                            name: '米娅',
                            icon: Icons.face_3_rounded,
                            color: AppColors.blue,
                            speaking: line?.speaker == 0,
                            reducedMotion: reducedMotion,
                          ),
                          _Character(
                            name: '里奥',
                            icon: Icons.face_6_rounded,
                            color: AppColors.green,
                            speaking: line?.speaker == 1,
                            reducedMotion: reducedMotion,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AnimatedSwitcher(
                          duration: reducedMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          child: line == null
                              ? const CircularProgressIndicator()
                              : Container(
                                  key: ValueKey(_index),
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: AppColors.locked),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.speaker == 0 ? '米娅' : '里奥',
                                        style: TextStyle(
                                          color: line.speaker == 0
                                              ? AppColors.blueDark
                                              : AppColors.greenDark,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        line.english,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        line.chinese,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: PushableButton(label: '结束表演', onPressed: _finish),
            ),
          ],
        ),
      ),
    );
  }
}

class _Character extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool speaking;
  final bool reducedMotion;

  const _Character({
    required this.name,
    required this.icon,
    required this.color,
    required this.speaking,
    required this.reducedMotion,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnimatedScale(
        scale: speaking ? 1.12 : 0.94,
        duration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 350),
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: speaking ? 0.2 : 0.08),
            border: Border.all(
              color: speaking ? color : AppColors.locked,
              width: 3,
            ),
          ),
          child: Icon(icon, size: 65, color: color),
        ),
      ),
      const SizedBox(height: 12),
      Text(name, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
