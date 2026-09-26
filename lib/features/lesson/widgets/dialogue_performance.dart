import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../app/theme.dart';
import '../dialogue_script.dart';

class DialoguePerformance extends StatefulWidget {
  final String unitId;
  final String unitTitle;
  final VoidCallback onFinished;

  const DialoguePerformance({
    super.key,
    required this.unitId,
    required this.unitTitle,
    required this.onFinished,
  });

  @override
  State<DialoguePerformance> createState() => _DialoguePerformanceState();
}

class _DialoguePerformanceState extends State<DialoguePerformance> {
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  DialogueScript? _script;
  Timer? _timer;
  int _index = 0;
  int _generation = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final script = await DialogueScript.load(widget.unitId);
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
    final words = line.english.split(RegExp(r'\s+')).length;
    final duration = Duration(
      milliseconds: (words * 400 + 1400).clamp(3200, 7800),
    );
    unawaited(_playVoice(line, _index + 1, generation));
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (!mounted || _finished || generation != _generation) return;
      if (_index + 1 == script.lines.length) {
        _finish();
      } else {
        setState(() => _index++);
        _playLine();
      }
    });
  }

  Future<void> _playVoice(
    DialogueLine line,
    int lineNumber,
    int generation,
  ) async {
    try {
      await _player.stop();
      await _tts.stop();
      if (!mounted || _finished || generation != _generation) return;
      await _player.play(
        AssetSource('audio/dialogues/${widget.unitId}_$lineNumber.mp3'),
      );
    } catch (_) {
      if (!mounted || _finished || generation != _generation) return;
      try {
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(0.45);
        if (mounted && !_finished && generation == _generation) {
          await _tts.speak(line.english);
        }
      } catch (_) {
        // 字幕和演出仍可继续。
      }
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _generation++;
    _timer?.cancel();
    unawaited(_player.stop());
    unawaited(_tts.stop());
    widget.onFinished();
  }

  @override
  void dispose() {
    _finished = true;
    _generation++;
    _timer?.cancel();
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
