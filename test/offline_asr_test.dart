// 开发机（Windows 宿主）验证内置 whisper tiny.en 模型识别效果。
// 缺少 dll/模型/wav 时自动跳过，不影响 CI 与其他平台。
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 本机 System32 里装过旧版 onnxruntime.dll（1.10 DML 版），Windows DLL 搜索
/// 顺序中系统目录优先于包目录，会抢先加载旧版导致
/// "The given version [28] is not supported, only version 1 to 10" 崩溃。
/// 用 SetDllDirectoryW 把包目录提到搜索最前面。仅影响宿主测试，
/// Android 上 .so 与 apk 同目录加载，无此问题。
void _preferPackageDllDir(String dir) {
  if (!Platform.isWindows) return;
  final kernel = DynamicLibrary.open('kernel32.dll');
  final setDir = kernel
      .lookupFunction<
        Int32 Function(Pointer<Uint16>),
        int Function(Pointer<Uint16>)
      >('SetDllDirectoryW');
  final units = dir.codeUnits;
  final buf = calloc<Uint16>(units.length + 1);
  for (var i = 0; i < units.length; i++) {
    buf[i] = units[i];
  }
  buf[units.length] = 0;
  setDir(buf);
  calloc.free(buf);
}

String? _resolveDllDir() {
  final config = File('.dart_tool/package_config.json');
  if (!Platform.isWindows || !config.existsSync()) return null;
  final data = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  for (final entry in data['packages'] as List<dynamic>) {
    final package = entry as Map<String, dynamic>;
    if (package['name'] != 'sherpa_onnx_windows') continue;
    final root = config.absolute.uri.resolve(package['rootUri'] as String);
    final rootDir = Directory.fromUri(root);
    return rootDir.absolute.uri.resolve('windows/').toFilePath();
  }
  return null;
}

void main() {
  final dllDir = _resolveDllDir();
  // 仓库路径含非 ASCII 字符时，可通过环境变量指定 ASCII 目录联接。
  final root = Directory(
    Platform.environment['GLOBAL_VILLAGE_ASR_TEST_ROOT'] ?? '.',
  ).absolute;
  final modelDir = root.uri.resolve('assets/models/whisper/');
  final encoder = File.fromUri(modelDir.resolve('tiny.en-encoder.int8.onnx'));
  final decoder = File.fromUri(modelDir.resolve('tiny.en-decoder.int8.onnx'));
  final tokens = File.fromUri(modelDir.resolve('tiny.en-tokens.txt'));
  final waveFile = File.fromUri(
    root.uri.resolve('.trae/sherpa-onnx-whisper-tiny.en/test_wavs/0.wav'),
  );
  final available =
      dllDir != null &&
      File('${dllDir}sherpa-onnx-c-api.dll').existsSync() &&
      !RegExp(r'[^\x00-\x7F]').hasMatch(root.path) &&
      encoder.existsSync() &&
      decoder.existsSync() &&
      tokens.existsSync() &&
      waveFile.existsSync();

  test(
    'whisper tiny.en 模型能识别英文测试音频',
    () {
      _preferPackageDllDir(dllDir!);
      sherpa.initBindings(dllDir);
      final recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            whisper: sherpa.OfflineWhisperModelConfig(
              encoder: encoder.path,
              decoder: decoder.path,
              language: 'en',
              task: 'transcribe',
            ),
            tokens: tokens.path,
            numThreads: 2,
          ),
        ),
      );
      final wave = sherpa.readWave(waveFile.path);
      final stream = recognizer.createStream();
      stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
      recognizer.decode(stream);
      final text = recognizer.getResult(stream).text.trim();
      stream.free();
      recognizer.free();
      // ignore: avoid_print
      print('WHISPER RESULT: "$text"');
      expect(text, isNotEmpty);
    },
    skip: !available,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
