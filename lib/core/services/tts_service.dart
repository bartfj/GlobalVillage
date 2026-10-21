import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/models/course.dart';
import '../../data/models/learning_language.dart';
import '../../data/sources/content_documents.dart';
import 'diagnostic_log.dart';

/// 发音服务：优先播放内置/已下载音频，缺失时回退系统 TTS（英语、中文）。
class TtsService {
  TtsService({this.documents});

  final ContentDocuments? documents;
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  static const englishLanguageCandidates = ['en-US', 'en-GB', 'en'];
  static const chineseLanguageCandidates = ['zh-CN', 'zh-TW', 'zh'];

  final Map<LearningLanguage, String> _resolvedVoices = {};
  LearningLanguage? _activeLanguage;
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

  Future<bool> _ensureInitialized(LearningLanguage language) async {
    // 梵文没有可靠语音，只播放本地录音。
    if (language == LearningLanguage.sanskrit) return false;
    if (_activeLanguage == language) return true;

    final cached = _resolvedVoices[language];
    if (cached != null) {
      if (await _applyLanguage(cached)) {
        _activeLanguage = language;
        return true;
      }
      _resolvedVoices.remove(language);
    }

    // 不预判语音包是否“已安装”：部分引擎能联网合成却报未安装，
    // 以 setLanguage 的实际结果为准。
    for (final voice in _languageCandidates(language)) {
      if (await _applyLanguage(voice)) {
        _resolvedVoices[language] = voice;
        _activeLanguage = language;
        return true;
      }
    }

    return false;
  }

  Future<bool> _applyLanguage(String voice) async {
    try {
      final result = await _tts.setLanguage(voice);
      if (!languageResultOk(result)) return false;
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      return true;
    } catch (error, stack) {
      recordDiagnosticError('tts', error, stack);
      return false;
    }
  }

  /// Android `setLanguage` 返回 LANG_AVAILABLE=0、LANG_COUNTRY_AVAILABLE=1、
  /// LANG_COUNTRY_VAR_AVAILABLE=2，负数才是缺失或不支持。
  static bool languageResultOk(Object? result) =>
      result == true || (result is int && result >= 0);

  static List<String> _languageCandidates(LearningLanguage language) =>
      switch (language) {
        LearningLanguage.chinese => chineseLanguageCandidates,
        LearningLanguage.english => englishLanguageCandidates,
        LearningLanguage.sanskrit => const [],
      };

  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 播放题目发音：内置/已下载 mp3 优先，缺失时回退对应语言的系统 TTS。
  Future<bool> speakExercise(Exercise exercise) async {
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

    final spoken = speakableText(exercise);
    if (spoken == null) return false;
    return speak(spoken, language: exercise.language);
  }

  static final RegExp _hanzi = RegExp(r'[\u4e00-\u9fff]');

  /// 供 TTS 朗读的文本。中文必须读汉字，拼音字母串会被引擎逐字母念出来。
  static String? speakableText(Exercise exercise) {
    switch (exercise.language) {
      case LearningLanguage.chinese:
        if (_hanzi.hasMatch(exercise.sentence)) return exercise.sentence;
        final support = exercise.support;
        if (support != null && _hanzi.hasMatch(support)) return support;
        return null;
      case LearningLanguage.sanskrit:
        return null;
      case LearningLanguage.english:
        final sentence = exercise.sentence.trim();
        return sentence.isEmpty ? null : sentence;
    }
  }

  /// Android flutter_tts：`1` 已入队；`0` 表示 QUEUE_FLUSH 下仍标记 speaking（常见于 stop 后立刻 speak）。
  static bool speakResultOk(Object? result) => result == 1 || result == true;

  Future<bool> speak(
    String text, {
    LearningLanguage language = LearningLanguage.english,
  }) async {
    if (text.trim().isEmpty) return false;
    final uttered = text.trim();
    try {
      // 先释放 AudioPlayer 焦点，否则部分机型 TTS 会无声
      try {
        await _player.stop();
      } catch (_) {}
      if (!await _ensureInitialized(language)) return false;
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
