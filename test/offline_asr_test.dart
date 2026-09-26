// 开发机（Windows 宿主）验证内置 whisper tiny.en 模型识别效果。
// 缺少 dll/模型/wav 时自动跳过，不影响 CI 与其他平台。
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
  final setDir = kernel.lookupFunction<Int32 Function(Pointer<Uint16>),
      int Function(Pointer<Uint16>)>('SetDllDirectoryW');
  final units = dir.codeUnits;
  final buf = calloc<Uint16>(units.length + 1);
  for (var i = 0; i < units.length; i++) {
    buf[i] = units[i];
  }
  buf[units.length] = 0;
  setDir(buf);
  calloc.free(buf);
}

const _dllDir =
    r'd:\workspace\github_code\地球村\.trae\sdk\pub-cache\hosted\pub.flutter-io.cn\sherpa_onnx_windows-1.13.8\windows';
// 用 ASCII junction 路径：C++ 侧读模型文件不支持中文路径（会解析成乱码报
// "version [28] not supported"）。D:\english_village 指向项目根。
const _modelDir = r'D:\english_village\assets\models\whisper';
const _wav = r'D:\english_village\.trae\sherpa-onnx-whisper-tiny.en\test_wavs\0.wav';

void main() {
  final available = File('$_dllDir\\sherpa-onnx-c-api.dll').existsSync() &&
      File('$_modelDir\\tiny.en-encoder.int8.onnx').existsSync() &&
      File(_wav).existsSync();

  test('whisper tiny.en 模型能识别英文测试音频', () {
    _preferPackageDllDir(_dllDir);
    sherpa.initBindings(_dllDir);
    final recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: '$_modelDir\\tiny.en-encoder.int8.onnx',
            decoder: '$_modelDir\\tiny.en-decoder.int8.onnx',
            language: 'en',
            task: 'transcribe',
          ),
          tokens: '$_modelDir\\tiny.en-tokens.txt',
          numThreads: 2,
        ),
      ),
    );
    final wave = sherpa.readWave(_wav);
    final stream = recognizer.createStream();
    stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
    recognizer.decode(stream);
    final text = recognizer.getResult(stream).text.trim();
    stream.free();
    recognizer.free();
    // ignore: avoid_print
    print('WHISPER RESULT: "$text"');
    expect(text, isNotEmpty);
  }, skip: !available, timeout: const Timeout(Duration(minutes: 3)));
}
