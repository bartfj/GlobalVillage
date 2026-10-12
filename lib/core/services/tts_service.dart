import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/models/course.dart';
import '../../data/models/learning_language.dart';

/// 英文发音服务：优先播放内置/网络音频，缺失时回退系统 TTS
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
    await _player.setVolume(1.0);
    _playerReady = true;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
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
  Future<bool> speakExercise(Exercise exercise) async {
    // Non-English pilot courses have no verified audio or ASR pipeline yet.
    if (exercise.language != LearningLanguage.english) return false;
    final relative = 'audio/listening/${exercise.id}.mp3';
    final bundlePath = 'assets/$relative';

    if (await _assetExists(bundlePath)) {
      try {
        await _ensurePlayerReady();
        await _tts.stop();
        await _player.stop();
        await _player
            .play(AssetSource(relative))
            .timeout(const Duration(seconds: 8));
        return true;
      } catch (_) {
        // 播放失败则回退 TTS
      }
    }

    return speak(exercise.sentence);
  }

  /// Android flutter_tts：`1` 已入队；`0` 表示 QUEUE_FLUSH 下仍标记 speaking（常见于 stop 后立刻 speak）。
  static bool speakResultOk(Object? result) =>
      result == 1 || result == true;

  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    final uttered = text.trim();
    try {
      // 先释放 AudioPlayer 焦点，否则部分机型 TTS 会无声
      try {
        await _player.stop();
      } catch (_) {}
      await _ensureInitialized();
      await _tts.stop();
      await _tts.setVolume(1.0);
      var result = await _tts.speak(uttered).timeout(const Duration(seconds: 8));
      if (speakResultOk(result)) return true;

      // stop→speak 竞态时引擎会回 0；短延迟后重试一次，避免误报「语音播放失败」
      if (result == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await _tts.stop();
        result = await _tts.speak(uttered).timeout(const Duration(seconds: 8));
        if (speakResultOk(result)) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 播放远程音频 URL（词典发音）；失败时回退 [speak]
  Future<void> speakUrlOrText(String? url, String fallbackText) async {
    if (url != null && url.trim().isNotEmpty) {
      try {
        await _ensurePlayerReady();
        await _tts.stop();
        await _player.stop();

        final started = Completer<bool>();
        late final StreamSubscription<PlayerState> sub;
        sub = _player.onPlayerStateChanged.listen((state) {
          if (state == PlayerState.playing || state == PlayerState.completed) {
            if (!started.isCompleted) started.complete(true);
          }
        });

        await _player.play(UrlSource(url.trim()));
        // play() 可能在缓冲前就返回；等真正开播，超时则停掉并回退 TTS
        final ok = await started.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => false,
        );
        await sub.cancel();
        if (ok) return;
        await _player.stop();
      } catch (_) {
        // 网络音频失败则回退 TTS
      }
    }
    await speak(fallbackText);
  }

  void dispose() {
    _player.dispose();
    _tts.stop();
  }
}
