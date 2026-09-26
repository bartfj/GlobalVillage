import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 内置离线语音识别（sherpa-onnx + Whisper tiny.en int8，纯本地推理）。
/// 用于设备没有系统语音识别服务（国产机无 Google 服务）时兜底打分。
class OfflineAsrService {
  OfflineAsrService._();
  static final OfflineAsrService instance = OfflineAsrService._();

  static const _modelFiles = [
    'tiny.en-encoder.int8.onnx',
    'tiny.en-decoder.int8.onnx',
    'tiny.en-tokens.txt',
  ];

  bool _bindingsReady = false;
  sherpa.OfflineRecognizer? _recognizer;
  bool _failed = false;

  /// 初始化绑定、释放模型、创建识别器。失败返回 false（调用方降级）。
  Future<bool> ensureReady() async {
    if (_recognizer != null) return true;
    if (_failed) return false;
    try {
      if (!_bindingsReady) {
        await sherpa.initBindingsAsync();
        _bindingsReady = true;
      }
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/whisper',
      );
      if (!dir.existsSync()) dir.createSync(recursive: true);
      for (final name in _modelFiles) {
        final f = File('${dir.path}/$name');
        if (!f.existsSync()) {
          final data = await rootBundle.load('assets/models/whisper/$name');
          f.writeAsBytesSync(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        }
      }
      _recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            whisper: sherpa.OfflineWhisperModelConfig(
              encoder: '${dir.path}/tiny.en-encoder.int8.onnx',
              decoder: '${dir.path}/tiny.en-decoder.int8.onnx',
              language: 'en',
              task: 'transcribe',
            ),
            tokens: '${dir.path}/tiny.en-tokens.txt',
            numThreads: 2,
          ),
        ),
      );
      return true;
    } catch (_) {
      _failed = true;
      return false;
    }
  }

  /// 识别 16kHz 单声道 PCM16 音频，返回识别文本。
  static String recognizePcm16({
    required sherpa.OfflineRecognizer recognizer,
    required Uint8List pcm16,
    int sampleRate = 16000,
  }) {
    final n = pcm16.length ~/ 2;
    final samples = Float32List(n);
    final bd = ByteData.sublistView(pcm16);
    for (var i = 0; i < n; i++) {
      samples[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    final stream = recognizer.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
    recognizer.decode(stream);
    final text = recognizer.getResult(stream).text;
    stream.free();
    return text;
  }

  /// 识别录音数据（实例方法，需先 ensureReady）。
  Future<String> recognize(Uint8List pcm16) async {
    final r = _recognizer;
    if (r == null) return '';
    return recognizePcm16(recognizer: r, pcm16: pcm16);
  }
}
