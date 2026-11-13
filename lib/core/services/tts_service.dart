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
  TtsService({
    this.documents,
    AudioPlayer? player,
    FlutterTts? tts,
    AssetBundle? assets,
  }) : _player = player ?? AudioPlayer(),
       _tts = tts ?? FlutterTts(),
       _assets = assets ?? rootBundle;

  final ContentDocuments? documents;
  final FlutterTts _tts;
  final AudioPlayer _player;
  final AssetBundle _assets;
  int _generation = 0;
  bool _disposed = false;
  Future<void> _requests = Future<void>.value();
  Future<void> _stopping = Future<void>.value();

  bool _current(int generation) => !_disposed && generation == _generation;
  Future<bool> _request(Future<bool> Function(int) action) {
    final generation = ++_generation;
    final pending = _requests.then((_) async {
      await _stopping;
      if (!_current(generation)) return false;
      return action(generation);
    });
    _requests = pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return pending;
  }

  Future<bool> _playSource(Source source, int generation) async {
    await _ensurePlayerReady();
    if (!_current(generation)) return false;
    await _tts.stop();
    if (!_current(generation)) return false;
    await _player.stop();
    if (!_current(generation)) return false;
    // AudioPlayer.play itself awaits source/cache preparation before native
    // resume. Prepare separately so cancellation is checked after those awaits.
    await _player.setSource(source).timeout(const Duration(seconds: 8));
    if (!_current(generation)) return false;
    await _player.resume().timeout(const Duration(seconds: 8));
    return _current(generation);
  }

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
      await _assets.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 播放题目发音：内置/已下载 mp3 优先，缺失时回退对应语言的系统 TTS。
  Future<bool> speakExercise(Exercise exercise) => _request((generation) async {
    final relative = 'audio/listening/${exercise.id}.mp3';
    final bundlePath = 'assets/$relative';
    final cached = await documents?.audioFilePath(relative);
    if (!_current(generation)) return false;
    if (cached != null) {
      try {
        return await _playSource(DeviceFileSource(cached), generation);
      } catch (error, stack) {
        recordDiagnosticError('tts', error, stack);
        if (!_current(generation)) return false;
      }
    }
    final exists = await _assetExists(bundlePath);
    if (!_current(generation)) return false;
    if (exists) {
      try {
        return await _playSource(AssetSource(relative), generation);
      } catch (error, stack) {
        recordDiagnosticError('tts', error, stack);
        if (!_current(generation)) return false;
      }
    }
    final spoken = speakableText(exercise);
    if (spoken == null) return false;
    return _speak(spoken, exercise.language, generation);
  });

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
  }) => text.trim().isEmpty
      ? Future<bool>.value(false)
      : _request((generation) => _speak(text.trim(), language, generation));

  Future<bool> _speak(
    String text,
    LearningLanguage language,
    int generation,
  ) async {
    if (!_current(generation)) return false;
    try {
      try {
        await _player.stop();
      } catch (_) {}
      if (!_current(generation)) return false;
      final initialized = await _ensureInitialized(language);
      if (!_current(generation) || !initialized) return false;
      await _tts.stop();
      if (!_current(generation)) return false;
      await _tts.setVolume(1.0);
      if (!_current(generation)) return false;
      var result = await _tts.speak(text).timeout(const Duration(seconds: 8));
      if (!_current(generation)) return false;
      if (speakResultOk(result)) return true;
      if (result == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!_current(generation)) return false;
        await _tts.stop();
        if (!_current(generation)) return false;
        result = await _tts.speak(text).timeout(const Duration(seconds: 8));
        return _current(generation) && speakResultOk(result);
      }
      return false;
    } catch (error, stack) {
      recordDiagnosticError('tts', error, stack);
      return false;
    }
  }

  /// Remote pronunciation shares the same cancellation identity as its fallback.
  Future<void> speakUrlOrText(String? url, String fallbackText) async {
    await _request((generation) async {
      if (url != null && url.trim().isNotEmpty) {
        StreamSubscription<PlayerState>? subscription;
        try {
          final started = Completer<bool>();
          subscription = _player.onPlayerStateChanged.listen((state) {
            if ((state == PlayerState.playing ||
                    state == PlayerState.completed) &&
                !started.isCompleted) {
              started.complete(true);
            }
          });
          final played = await _playSource(UrlSource(url.trim()), generation);
          if (!_current(generation)) return false;
          if (played) {
            final ok = await started.future.timeout(
              const Duration(seconds: 3),
              onTimeout: () => false,
            );
            if (!_current(generation)) return false;
            if (ok) return true;
          }
          await _player.stop();
        } catch (error, stack) {
          recordDiagnosticError('tts', error, stack);
        } finally {
          await subscription?.cancel();
        }
      }
      if (!_current(generation) || fallbackText.trim().isEmpty) return false;
      return _speak(fallbackText.trim(), LearningLanguage.english, generation);
    });
  }

  /// Invalidate queued/preparing requests synchronously, then release channels.
  Future<void> stop() {
    ++_generation;
    return _stopping = Future.wait<void>([
      _player.stop().catchError((Object _) {}),
      _tts.stop().then<void>((_) {}).catchError((Object _) {}),
    ]).then<void>((_) {});
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    unawaited(_player.dispose().catchError((Object _) {}));
    unawaited(_tts.stop().then<void>((_) {}).catchError((Object _) {}));
  }
}
