import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/models/course.dart';

/// 英文发音服务：优先播放内置音频，缺失时回退系统 TTS
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    _initialized = true;
  }

  /// 播放题目发音：内置 mp3 优先，失败回退系统 TTS
  Future<void> speakExercise(Exercise exercise) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/listening/${exercise.id}.mp3'));
      return;
    } catch (_) {
      // 内置音频缺失，回退系统 TTS
    }
    await speak(exercise.sentence);
  }

  Future<void> speak(String text) async {
    try {
      await _ensureInitialized();
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // TTS 不可用时静默降级
    }
  }

  void dispose() {
    _player.dispose();
    _tts.stop();
  }
}
