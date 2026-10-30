import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/services/diagnostic_log.dart';
import '../../../core/services/offline_asr_service.dart';
import '../../../core/utils/similarity.dart';
import '../../../data/models/course.dart';
import 'tappable_phonetic_text.dart';

/// 系统识别报忙、客户端错误或音频通道冲突时值得自动再试一次。
/// 没听清、超时不属于这类失败。
bool speechEngineShouldRetry(String errorMsg, bool permanent, int attempts) {
  if (permanent || attempts >= 1) return false;
  final msg = errorMsg.toLowerCase();
  return msg.contains('busy') ||
      msg.contains('client') ||
      msg.contains('audio');
}

/// 跟读题：播放原音 -> 用户跟读 -> 语音识别打分。
/// 优先用系统语音识别；系统无识别服务时自动切换内置离线识别
/// （sherpa-onnx，纯本地）；麦克风权限被拒或识别不可用时，
/// 「跟读完成」走跳过（不计正确分），而非满分通过。
class SpeakingWidget extends ConsumerStatefulWidget {
  final Exercise exercise;
  final bool enabled;
  final ValueChanged<String> onChanged;

  /// 降级跳过（不计分）；未提供时回退为 onChanged 空串
  final VoidCallback? onSkip;

  const SpeakingWidget({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.onChanged,
    this.onSkip,
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

  /// 正在打开识别器。这段时间按钮不再连点，避免多次 initialize 叠在一起。
  bool _preparing = false;

  /// 系统识别是否已经初始化过。重复 initialize 会让 Android 识别器偶发启动失败。
  bool _speechReady = false;

  /// 本轮是否已经收到最终结果，避免状态回调把成功结果清掉。
  bool _gotFinal = false;

  /// 平台是否已经回调 listening。listen() 返回时这个状态可能还没到。
  bool _engineListening = false;

  /// 本轮因识别器忙或音频冲突已经自动重试的次数。
  int _listenAttempts = 0;

  /// 错误回调已经结束或安排了重试，调用方不要再重试一次。
  bool _startFailureHandled = false;

  /// 自动重试还没结束，避免按钮提前恢复成可连点。
  bool _retryPending = false;

  Timer? _statusGrace;

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
    _statusGrace?.cancel();
    _recSub?.cancel();
    _recorder.dispose();
    _speech.stop();
    super.dispose();
  }

  void _speak() {
    ref.read(ttsServiceProvider).speakExercise(widget.exercise);
  }

  Future<void> _toggleListening() async {
    if (_preparing) return;
    if (_listening) {
      if (_usingOffline) {
        await _stopOffline();
      } else {
        _gotFinal = true;
        _statusGrace?.cancel();
        await _speech.stop();
        _onListenDone();
      }
      return;
    }
    setState(() => _preparing = true);
    try {
      // 原音还在播时系统识别经常启动失败，读了也没有任何结果。
      await ref.read(ttsServiceProvider).stop();
      var ok = _speechReady;
      if (!ok) {
        try {
          ok = await _speech.initialize(
            onError: _onSpeechError,
            onStatus: _onSpeechStatus,
          );
        } catch (error, stack) {
          recordDiagnosticError('speech', error, stack);
          ok = false;
        }
        _speechReady = ok;
      }
      if (!mounted) return;
      if (ok) {
        _listenAttempts = 0;
        final started = await _startSystemListening();
        if (!started && mounted) {
          _listenAttempts = 1;
          final retried = await _startSystemListening();
          if (!retried && mounted && !_listening) _onListenDone();
        }
        return;
      }
      // 系统识别不可用：权限被拒 -> 降级；否则切换内置离线识别
      bool perm = false;
      try {
        perm = await _speech.hasPermission;
      } catch (error, stack) {
        recordDiagnosticError('speech', error, stack);
      }
      if (!mounted) return;
      if (!perm) {
        setState(() {
          _available = false;
          _failReason = 'permission';
        });
        return;
      }
      await _startOfflineListening();
    } finally {
      if (mounted && !_retryPending) setState(() => _preparing = false);
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    recordDiagnosticError('speech', error.errorMsg);
    if (!mounted || !_listening || _usingOffline || _gotFinal) return;
    _startFailureHandled = true;
    if (speechEngineShouldRetry(
      error.errorMsg,
      error.permanent,
      _listenAttempts,
    )) {
      _listenAttempts++;
      _listening = false;
      _retryPending = true;
      _stopTimer?.cancel();
      _statusGrace?.cancel();
      unawaited(_retrySystemListening());
      return;
    }
    _gotFinal = true;
    _onListenDone();
  }

  void _onSpeechStatus(String status) {
    if (status == 'listening') {
      _engineListening = true;
      return;
    }
    if (status != 'done' && status != 'notListening') return;
    if (!_listening || _usingOffline || _gotFinal) return;
    // 最终结果有时比状态晚到，稍等一下再判定没听清。
    _statusGrace?.cancel();
    _statusGrace = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _listening && !_gotFinal && !_usingOffline) {
        _onListenDone();
      }
    });
  }

  Future<void> _retrySystemListening() async {
    if (mounted) setState(() => _preparing = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted || _listening) return;
      try {
        await _speech.cancel();
      } catch (error, stack) {
        recordDiagnosticError('speech', error, stack);
      }
      try {
        await ref.read(ttsServiceProvider).stop();
      } catch (_) {}
      if (!mounted || _listening) return;
      final started = await _startSystemListening();
      if (!started && mounted && !_listening) _onListenDone();
    } finally {
      _retryPending = false;
      if (mounted) setState(() => _preparing = false);
    }
  }

  /// 返回识别器是否真的开始听。平台可能直接拒绝，此时不能停在「正在聆听」。
  Future<bool> _startSystemListening() async {
    _gotFinal = false;
    _engineListening = false;
    _startFailureHandled = false;
    _statusGrace?.cancel();
    try {
      if (_speech.isListening) {
        await _speech.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (!mounted) return false;
      setState(() {
        _usingOffline = false;
        _listening = true;
        _recognized = '';
        _lastScore = null;
        _emptyResult = false;
      });
      HapticFeedback.lightImpact();
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: 'en_US',
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!mounted || !_listening) return;
          if (result.recognizedWords.isNotEmpty) {
            setState(() => _recognized = result.recognizedWords);
          }
          if (result.finalResult) {
            _gotFinal = true;
            _listenAttempts = 0;
            _stopTimer?.cancel();
            _statusGrace?.cancel();
            _onListenDone();
          }
        },
      );
    } catch (error, stack) {
      recordDiagnosticError('speech', error, stack);
      if (mounted) setState(() => _listening = false);
      return false;
    }
    if (!mounted) return false;
    // 识别器是否真的开听是异步通知的。空等一会儿，避免把还没起来的会话当成正在听。
    final deadline = DateTime.now().add(const Duration(milliseconds: 800));
    while (mounted &&
        !_engineListening &&
        !_speech.isListening &&
        !_startFailureHandled &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return false;
    if (_startFailureHandled) return true;
    if (!_engineListening && !_speech.isListening) {
      setState(() => _listening = false);
      return false;
    }
    // 兜底：系统服务无响应（连接中断等）20 秒后强制结束，给出回退入口
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && _listening && !_usingOffline) {
        _speech.stop();
        _onListenDone();
      }
    });
    return true;
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
    } catch (error, stack) {
      recordDiagnosticError('speech', error, stack);
    }
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
    } catch (error, stack) {
      recordDiagnosticError('speech', error, stack);
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
    } catch (error, stack) {
      recordDiagnosticError('speech', error, stack);
    }
    if (!mounted) return;
    setState(() => _listening = false);
    final bytes = Uint8List.fromList(_pcmChunks);
    String text = '';
    if (bytes.length > 3200) {
      // 至少 0.1 秒音频才识别
      try {
        text = (await OfflineAsrService.instance.recognize(bytes)).trim();
      } catch (error, stack) {
        recordDiagnosticError('speech', error, stack);
      }
    }
    if (!mounted) return;
    setState(() => _recognized = text);
    _onListenDone();
  }

  void _onListenDone() {
    if (!mounted) return;
    _stopTimer?.cancel();
    _statusGrace?.cancel();
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
    widget.onChanged(score >= _passScore ? widget.exercise.sentence : spoken);
  }

  /// 降级：识别服务不可用时，确认已跟读则跳过（不计满分）
  void _markDone() {
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      widget.onChanged('');
    }
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
                  child: TappablePhoneticText(
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
              onTap: widget.enabled && !_preparing ? _toggleListening : null,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listening || _preparing
                      ? AppColors.red
                      : AppColors.green,
                  border: Border(
                    bottom: BorderSide(
                      color: _listening || _preparing
                          ? AppColors.redDark
                          : AppColors.greenDark,
                      width: 5,
                    ),
                  ),
                ),
                child: _preparing && !_listening
                    ? const Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _listening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _preparing && !_listening
                ? '正在打开麦克风…'
                : (_listening
                      ? '正在聆听…请直接读出句子'
                      : '点击麦克风，大声读出上面的句子'),
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
            const Text('没听清，再试一次；或确认已跟读后点"跟读完成"', textAlign: TextAlign.center),
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
