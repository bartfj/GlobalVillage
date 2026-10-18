import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/models/course.dart';
import '../../data/models/learning_language.dart';
import '../../data/sources/content_documents.dart';
import 'diagnostic_log.dart';

/// 英文发音服务：优先播放内置/网络音频，缺失时回退系统 TTS
class TtsService {
  TtsService({this.documents});

  final ContentDocuments? documents;
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  static const englishLanguageCandidates = ['en-US', 'en-GB', 'en'];

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

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;

    final language = await _installedEnglishLanguage();
    if (language == null) return false;

    final result = await _tts.setLanguage(language);
    if (!speakResultOk(result)) return false;

    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    _initialized = true;
    return true;
  }

  /// 已安装的英语语音。Android 用语音包是否落地判断，其它平台用系统是否提供该语言。
  Future<String?> _installedEnglishLanguage() async {
    for (final language in englishLanguageCandidates) {
      if (await _englishVoiceReady(language)) return language;
    }

    return null;
  }

  Future<bool> _englishVoiceReady(String language) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return await _tts.isLanguageInstalled(language) == true;
    }

    return await _tts.isLanguageAvailable(language) == true;
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
    final cached = await documents?.audioFilePath(relative);

    if (cached != null) {
      try {
        await _ensurePlayerReady();
        await _tts.stop();
        await _player.stop();
        await _player
            .play(DeviceFileSource(cached))
            .timeout(const Duration(seconds: 8));
        return true;
      } catch (error, stack) {
        recordDiagnosticError('tts', error, stack);
      }
    }

    if (await _assetExists(bundlePath)) {
      try {
        await _ensurePlayerReady();
        await _tts.stop();
        await _player.stop();
        await _player
            .play(AssetSource(relative))
            .timeout(const Duration(seconds: 8));
        return true;
      } catch (error, stack) {
        recordDiagnosticError('tts', error, stack);
        // 播放失败则回退 TTS
      }
    }

    return speak(exercise.sentence);
  }

  /// Android flutter_tts：`1` 已入队；`0` 表示 QUEUE_FLUSH 下仍标记 speaking（常见于 stop 后立刻 speak）。
  static bool speakResultOk(Object? result) => result == 1 || result == true;

  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    final uttered = text.trim();
    try {
      // 先释放 AudioPlayer 焦点，否则部分机型 TTS 会无声
      try {
        await _player.stop();
      } catch (_) {}
      if (!await _ensureInitialized()) return false;
      await _tts.stop();
      await _tts.setVolume(1.0);
      var result = await _tts
          .speak(uttered)
          .timeout(const Duration(seconds: 8));
      if (speakResultOk(result)) return true;

      // stop→speak 竞态时引擎会回 0；短延迟后重试一次，避免误报「语音播放失败」
      if (result == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await _tts.stop();
        result = await _tts.speak(uttered).timeout(const Duration(seconds: 8));
        if (speakResultOk(result)) return true;
      }
      return false;
    } catch (error, stack) {
      recordDiagnosticError('tts', error, stack);
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
      } catch (error, stack) {
        recordDiagnosticError('tts', error, stack);
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
