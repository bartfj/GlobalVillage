import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../../data/models/sanskrit_sound.dart';
import '../../data/repositories/sanskrit_audio_repository.dart';
import 'diagnostic_log.dart';

enum SanskritPlaybackResult { completed, cancelled, failed }

abstract interface class SanskritSoundPlayer {
  Future<void> play(String path, double rate);
  Future<void> stop();
  Future<void> dispose();
}

class _DeviceSoundPlayer implements SanskritSoundPlayer {
  final AudioPlayer _player = AudioPlayer();
  Completer<void>? _finished;
  bool _ready = false;
  int _epoch = 0;

  @override
  Future<void> play(String path, double rate) async {
    final epoch = ++_epoch;
    if (!_ready) {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
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
      if (epoch != _epoch) return;
      _ready = true;
    }
    final finished = Completer<void>();
    _finished = finished;
    final subscription = _player.onPlayerComplete.listen(
      (_) {
        if (!finished.isCompleted) finished.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!finished.isCompleted) finished.completeError(error, stack);
      },
    );
    try {
      await _player.setSource(DeviceFileSource(path));
      if (epoch != _epoch) return;
      await _player.setPlaybackRate(rate);
      if (epoch != _epoch) return;
      await _player.setVolume(1);
      if (epoch != _epoch) return;
      await _player.resume();
      await finished.future.timeout(const Duration(seconds: 12));
    } finally {
      await subscription.cancel();
      if (identical(_finished, finished)) _finished = null;
    }
  }

  @override
  Future<void> stop() async {
    ++_epoch;
    final finished = _finished;
    if (finished != null && !finished.isCompleted) finished.complete();
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}

/// 单路播放，换字母、退出或进入后台会取消当前序列；不回退系统 TTS。
class SanskritAudioService {
  SanskritAudioService({required this.repository, SanskritSoundPlayer? player})
    : _player = player ?? _DeviceSoundPlayer();

  final Future<SanskritAudioRepository> repository;
  final SanskritSoundPlayer _player;
  Future<void> _tail = Future<void>.value();
  Completer<void>? _cancel;
  int _generation = 0;
  bool _disposed = false;

  Future<SanskritPlaybackResult> play(
    SanskritSound sound, {
    double rate = 1,
    int repetitions = 1,
  }) {
    if (_disposed) return Future.value(SanskritPlaybackResult.cancelled);
    if (![0.75, 1.0].contains(rate) || ![1, 3].contains(repetitions)) {
      throw ArgumentError('Unsupported Sanskrit playback settings');
    }
    final generation = ++_generation;
    _signalCancel();
    final cancel = Completer<void>();
    _cancel = cancel;
    final result = _tail.then(
      (_) => _play(sound, rate, repetitions, generation, cancel),
    );
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  Future<SanskritPlaybackResult> _play(
    SanskritSound sound,
    double rate,
    int repetitions,
    int generation,
    Completer<void> cancel,
  ) async {
    if (!_current(generation)) return SanskritPlaybackResult.cancelled;
    try {
      final path = await Future.any<String?>([
        repository.then((repo) => repo.fileFor(sound)),
        cancel.future.then((_) => null),
      ]);
      if (!_current(generation) || path == null) {
        return SanskritPlaybackResult.cancelled;
      }
      for (var i = 0; i < repetitions; i++) {
        final playback = _player
            .play(path, rate)
            .timeout(const Duration(seconds: 15));
        await Future.any<void>([playback, cancel.future]);
        // Wait for the native play operation to settle after cancellation, so a
        // delayed source preparation cannot restart audio after leaving a page.
        await _player.stop();
        await playback;
        if (!_current(generation)) return SanskritPlaybackResult.cancelled;
        if (i + 1 < repetitions) {
          await Future.any<void>([
            Future<void>.delayed(const Duration(milliseconds: 500)),
            cancel.future,
          ]);
          if (!_current(generation)) return SanskritPlaybackResult.cancelled;
        }
      }
      return SanskritPlaybackResult.completed;
    } catch (error, stack) {
      recordDiagnosticError('sanskrit-audio', error, stack);
      return _current(generation)
          ? SanskritPlaybackResult.failed
          : SanskritPlaybackResult.cancelled;
    } finally {
      try {
        await _player.stop();
      } catch (_) {}
    }
  }

  void _signalCancel() {
    final cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
  }

  Future<void> stop() async {
    ++_generation;
    _signalCancel();
    await _tail;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _player.dispose();
  }
}
