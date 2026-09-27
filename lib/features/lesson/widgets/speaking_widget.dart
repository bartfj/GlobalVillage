import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/services/offline_asr_service.dart';
import '../../../core/utils/similarity.dart';
import '../../../data/models/course.dart';

/// 跟读题：播放原音 -> 用户跟读 -> 语音识别打分。
/// 优先用系统语音识别；系统无识别服务时自动切换内置离线识别
/// （sherpa-onnx，纯本地）；麦克风权限被拒时降级为"跟读完成"直接通过。
class SpeakingWidget extends ConsumerStatefulWidget {
  final Exercise exercise;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const SpeakingWidget({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.onChanged,
  });

  @override
  ConsumerState<SpeakingWidget> createState() => _SpeakingWidgetState();
}

class _SpeakingWidgetState extends ConsumerState<SpeakingWidget> {
  static const _passScore = 0.6;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _recSub;
  Timer? _stopTimer;
  final List<int> _pcmChunks = [];
  bool _usingOffline = false;
  bool _available = true;
  bool _listening = false;
  String _recognized = '';
  double? _lastScore;

  /// 离线路径静音检测：是否已检测到说话、说话后累计静音时长（ms）
  bool _speechDetected = false;
  int _silenceMs = 0;

  /// 峰值幅度阈值：高于该值视为"在说话"（16bit PCM，满幅 32767）
  static const _silencePeakThreshold = 800;

  /// 与系统路径 pauseFor 一致：说话后连续静音达到该时长即提前停止录音
  static const _silenceStopMs = 3000;

  /// 识别结束但没听清任何内容（用户没说话/环境太安静/服务无响应）
  bool _emptyResult = false;

  /// 降级原因：permission=麦克风权限被拒（可重试），service=识别引擎不可用
  String? _failReason;

  @override
  void initState() {
    super.initState();
    // 进入题目自动播放一遍原音
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _recSub?.cancel();
    _recorder.dispose();
    _speech.stop();
    super.dispose();
  }

  void _speak() {
    ref.read(ttsServiceProvider).speakExercise(widget.exercise);
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      if (_usingOffline) {
        await _stopOffline();
      } else {
        await _speech.stop();
        _onListenDone();
      }
      return;
    }
    bool ok;
    try {
      ok = await _speech.initialize();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      _startSystemListening();
      return;
    }
    // 系统识别不可用：权限被拒 -> 降级；否则切换内置离线识别
    bool perm = false;
    try {
      perm = await _speech.hasPermission;
    } catch (_) {}
    if (!mounted) return;
    if (!perm) {
      setState(() {
        _available = false;
        _failReason = 'permission';
      });
      return;
    }
    await _startOfflineListening();
  }

  void _startSystemListening() {
    HapticFeedback.lightImpact();
    setState(() {
      _usingOffline = false;
      _listening = true;
      _recognized = '';
      _lastScore = null;
      _emptyResult = false;
    });
    try {
      _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: 'en_US',
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 3),
        ),
        onResult: (result) {
          if (!mounted) return;
          if (result.finalResult) _stopTimer?.cancel();
          setState(() => _recognized = result.recognizedWords);
          if (result.finalResult) _onListenDone();
        },
      );
      // 兜底：系统服务无响应（连接中断等）20 秒后强制结束，给出回退入口
      _stopTimer?.cancel();
      _stopTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && _listening) {
          _speech.stop();
          _onListenDone();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _available = false;
          _failReason = 'service';
        });
      }
    }
  }

  /// 内置离线识别：录音 16kHz 单声道 PCM，停止后本地推理打分
  Future<void> _startOfflineListening() async {
    final ready = await OfflineAsrService.instance.ensureReady();
    if (!mounted) return;
    if (!ready) {
      setState(() {
        _available = false;
        _failReason = 'service';
      });
      return;
    }
    bool perm = false;
    try {
      perm = await _recorder.hasPermission();
    } catch (_) {}
    if (!mounted) return;
    if (!perm) {
      setState(() {
        _available = false;
        _failReason = 'permission';
      });
      return;
    }
    try {
      _pcmChunks.clear();
      _speechDetected = false;
      _silenceMs = 0;
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _recSub = stream.listen((chunk) {
        _pcmChunks.addAll(chunk);
        // 静音检测：本块峰值超过阈值视为"在说话"，重置静音计时；
        // 说话后连续静音达到 3 秒，提前结束录音（与系统路径一致）
        if (_peakAmplitude(chunk) > _silencePeakThreshold) {
          _speechDetected = true;
          _silenceMs = 0;
        } else if (_speechDetected && _listening) {
          // 16kHz 16bit 单声道：每毫秒 32 字节
          _silenceMs += chunk.length ~/ 32;
          if (_silenceMs >= _silenceStopMs) {
            _stopOffline();
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _available = false;
          _failReason = 'service';
        });
      }
      return;
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _usingOffline = true;
      _listening = true;
      _recognized = '';
      _lastScore = null;
      _emptyResult = false;
    });
    _stopTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _listening) _stopOffline();
    });
  }

  /// 计算 16bit 小端 PCM 数据块的峰值幅度
  int _peakAmplitude(List<int> chunk) {
    var peak = 0;
    for (var i = 0; i + 1 < chunk.length; i += 2) {
      var sample = chunk[i] | (chunk[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      final abs = sample < 0 ? -sample : sample;
      if (abs > peak) peak = abs;
    }
    return peak;
  }

  Future<void> _stopOffline() async {
    if (!_listening) return; // 防重入：静音检测可能在订阅取消前连续触发
    _listening = false;
    _stopTimer?.cancel();
    await _recSub?.cancel();
    _recSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _listening = false);
    final bytes = Uint8List.fromList(_pcmChunks);
    String text = '';
    if (bytes.length > 3200) {
      // 至少 0.1 秒音频才识别
      try {
        text = (await OfflineAsrService.instance.recognize(bytes)).trim();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _recognized = text);
    _onListenDone();
  }

  void _onListenDone() {
    if (!mounted) return;
    _stopTimer?.cancel();
    final spoken = _recognized.trim();
    final score = spoken.isEmpty
        ? 0.0
        : sentenceSimilarity(widget.exercise.sentence, spoken);
    setState(() {
      _listening = false;
      _lastScore = score;
      _emptyResult = spoken.isEmpty;
    });
    if (spoken.isEmpty) return;
    // 达标则提交原句（判对）；不达标提交识别原文（判错，触发重做）
    widget.onChanged(
      score >= _passScore ? widget.exercise.sentence : spoken,
    );
  }

  /// 降级：识别服务不可用时，确认已跟读直接通过
  void _markDone() {
    widget.onChanged(widget.exercise.sentence);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('跟读练习', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          widget.exercise.prompt,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.lockedDark),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.exercise.sentence,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _speak,
                  icon: const Icon(
                    Icons.volume_up_rounded,
                    color: AppColors.blue,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (_available) ...[
          Center(
            child: GestureDetector(
              onTap: widget.enabled ? _toggleListening : null,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listening ? AppColors.red : AppColors.green,
                  border: Border(
                    bottom: BorderSide(
                      color: _listening
                          ? AppColors.redDark
                          : AppColors.greenDark,
                      width: 5,
                    ),
                  ),
                ),
                child: Icon(
                  _listening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _listening ? '正在聆听…说完会自动停止' : '点击麦克风，大声读出上面的句子',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_recognized.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '识别结果：$_recognized',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (_lastScore != null) ...[
            const SizedBox(height: 8),
            Text(
              _lastScore! >= _passScore
                  ? '相似度 ${(_lastScore! * 100).round()}%，很像了！点"检查"提交'
                  : '相似度 ${(_lastScore! * 100).round()}%，再试一次或点"检查"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _lastScore! >= _passScore
                    ? AppColors.greenDark
                    : AppColors.redDark,
              ),
            ),
          ],
          if (_emptyResult) ...[
            const SizedBox(height: 16),
            const Text(
              '没听清，再试一次；或确认已跟读后点"跟读完成"',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: widget.enabled ? _markDone : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('跟读完成'),
              ),
            ),
          ],
        ] else ...[
          const Icon(
            Icons.mic_off_rounded,
            size: 48,
            color: AppColors.lockedDark,
          ),
          const SizedBox(height: 12),
          Text(
            _failReason == 'permission'
                ? '麦克风权限未开启，请先到系统设置中允许本应用使用麦克风，再点重试'
                : '当前设备不支持语音识别，请跟着原音朗读后点击完成',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_failReason == 'permission') ...[
                  TextButton.icon(
                    onPressed: widget.enabled
                        ? () => setState(() {
                              _available = true;
                              _failReason = null;
                            })
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                  const SizedBox(width: 12),
                ],
                TextButton.icon(
                  onPressed: widget.enabled ? _markDone : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('跟读完成'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
