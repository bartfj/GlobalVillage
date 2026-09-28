import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/models/course.dart';

/// 英文发音服务：优先播放内置音频，缺失时回退系统 TTS
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;
  bool _playerReady = false;

  Future<void> _ensurePlayerReady() async {
    if (_playerReady) return;
    // 走媒体音量通道，避免部分机型仅调铃声音量时听不到
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {},
        ),
      ),
    );
    _playerReady = true;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    _initialized = true;
  }

  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 播放题目发音：内置 mp3 优先，缺失/失败回退系统 TTS
  Future<void> speakExercise(Exercise exercise) async {
    final relative = 'audio/listening/${exercise.id}.mp3';
    final bundlePath = 'assets/$relative';

    if (await _assetExists(bundlePath)) {
      try {
        await _ensurePlayerReady();
        await _player.stop();
        await _player.play(AssetSource(relative));
        return;
      } catch (_) {
        // 播放失败则回退 TTS
      }
    }

    await speak(exercise.sentence);
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
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
