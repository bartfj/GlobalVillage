import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:english_village/core/services/tts_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/sources/content_documents.dart';

class ControlledAudioPlayer implements AudioPlayer {
  Completer<void>? contextWait, sourceWait;
  @override
  Source? source;
  final starts = <Source>[];
  int stops = 0;
  final events = StreamController<PlayerState>.broadcast();
  @override
  Stream<PlayerState> get onPlayerStateChanged => events.stream;
  @override
  Future<void> setAudioContext(AudioContext context) async {
    await contextWait?.future;
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> setSource(Source source) async {
    await sourceWait?.future;
    this.source = source;
  }

  @override
  Future<void> resume() async {
    starts.add(source!);
    events.add(PlayerState.playing);
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    await setSource(source);
    await resume();
  }

  @override
  Future<void> dispose() async {
    await events.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ControlledSpeechEngine implements FlutterTts {
  Completer<void>? languageWait, volumeWait;
  final spoken = <String>[];
  final results = <dynamic>[];
  int stops = 0;
  @override
  Future<dynamic> setLanguage(String language) async {
    await languageWait?.future;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;
  @override
  Future<dynamic> setVolume(double volume) async {
    await volumeWait?.future;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    return results.isEmpty ? 1 : results.removeAt(0);
  }

  @override
  Future<dynamic> stop() async {
    stops++;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Models Android's prepared callback: changing source while playing can start
/// that source even without another Dart resume call.
class PerCallSourcePlayer extends ControlledAudioPlayer {
  final barriers = <Completer<void>>[];
  final implicitStarts = <Source>[];
  int sourceCalls = 0;
  bool playing = false;
  @override
  Future<void> setSource(Source value) async {
    final call = sourceCalls++;
    if (call < barriers.length) await barriers[call].future;
    source = value;
    if (playing) implicitStarts.add(value);
  }

  @override
  Future<void> stop() async {
    playing = false;
    await super.stop();
  }

  @override
  Future<void> resume() async {
    playing = true;
    await super.resume();
  }
}

class ControlledAssets extends CachingAssetBundle {
  Completer<void>? waiting;
  bool exists = true;
  @override
  Future<ByteData> load(String key) async {
    await waiting?.future;
    if (!exists) throw StateError('no asset');
    return ByteData(2);
  }
}

class ControlledDocuments implements ContentDocuments {
  Completer<void>? waiting;
  String? path;
  @override
  Future<String?> audioFilePath(String relativePath) async {
    await waiting?.future;
    return path;
  }

  @override
  Future<String?> packJson(String packId) async => null;
  @override
  Future<void> dropPack(String packId) async {}
}

const cancellationExercise = Exercise(
  id: 'mp_cancel',
  type: ExerciseType.speaking,
  prompt: '',
  sentence: 'I am Tom.',
  answer: 'I am Tom.',
  options: [],
);

void main() {
  for (final location in ['asset', 'cached']) {
    testWidgets(
      'timed out $location raw source drains before a newer source can play',
      (tester) async {
        final oldReady = Completer<void>();
        final newReady = Completer<void>()..complete();
        final player = PerCallSourcePlayer()
          ..barriers.addAll([oldReady, newReady]);
        final tts = ControlledSpeechEngine();
        final documents = ControlledDocuments();
        if (location == 'cached') documents.path = 'old-cache.mp3';
        final service = TtsService(
          player: player,
          tts: tts,
          assets: ControlledAssets(),
          documents: documents,
        );
        addTearDown(service.dispose);
        bool? oldResult;
        service
            .speakExercise(cancellationExercise)
            .then((value) => oldResult = value);
        await tester.pump();
        expect(player.sourceCalls, 1);
        await tester.pump(const Duration(seconds: 9));
        await tester.pump();
        if (location == 'cached') documents.path = 'new-cache.mp3';
        final next = service.speakExercise(
          const Exercise(
            id: 'next',
            type: ExerciseType.speaking,
            prompt: '',
            sentence: 'I need a pen.',
            answer: 'I need a pen.',
            options: [],
          ),
        );
        await tester.pump();
        oldReady.complete();
        await tester.pump();
        await tester.pump();
        expect(await next, true);
        final source = player.source;
        expect(
          location == 'asset'
              ? (source as AssetSource).path
              : (source as DeviceFileSource).path,
          location == 'asset' ? 'audio/listening/next.mp3' : 'new-cache.mp3',
        );
        expect(
          player.implicitStarts,
          isEmpty,
          reason:
              'Late old preparation must not replace a playing newer source',
        );
        expect(player.starts.length, 1);
        expect(player.starts.single, source);
        expect(oldResult, false);
        expect(tts.spoken, isEmpty);
      },
    );
  }
  testWidgets(
    'source timeout returns failure while late preparation stays stopped',
    (tester) async {
      final ready = Completer<void>();
      final player = PerCallSourcePlayer()..barriers.add(ready);
      final tts = ControlledSpeechEngine();
      final service = TtsService(
        player: player,
        tts: tts,
        assets: ControlledAssets(),
      );
      addTearDown(service.dispose);
      bool? result;
      service
          .speakExercise(cancellationExercise)
          .then((value) => result = value);
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      expect(result, false);
      expect(tts.spoken, isEmpty);
      ready.complete();
      await tester.pump();
      expect(player.starts, isEmpty);
      expect(player.implicitStarts, isEmpty);
    },
  );
  testWidgets(
    'stop remains prompt while timed out raw source holds a queued request',
    (tester) async {
      final ready = Completer<void>();
      final player = PerCallSourcePlayer()..barriers.add(ready);
      final service = TtsService(
        player: player,
        tts: ControlledSpeechEngine(),
        assets: ControlledAssets(),
      );
      addTearDown(service.dispose);
      final old = service.speakExercise(cancellationExercise);
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      final next = service.speakExercise(cancellationExercise);
      await tester.pump();
      var stopped = false;
      service.stop().then((_) => stopped = true);
      await tester.pump();
      expect(
        stopped,
        true,
        reason: 'Navigation/microphone stop must not await source draining',
      );
      ready.complete();
      await tester.pump();
      await Future.wait([old, next]);
      expect(player.starts, isEmpty);
      expect(player.implicitStarts, isEmpty);
    },
  );
  testWidgets(
    'late source failure after timeout releases the queue without old playback',
    (tester) async {
      final ready = Completer<void>();
      final player = PerCallSourcePlayer()..barriers.add(ready);
      final service = TtsService(
        player: player,
        tts: ControlledSpeechEngine(),
        assets: ControlledAssets(),
      );
      addTearDown(service.dispose);
      final old = service.speakExercise(cancellationExercise);
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      final next = service.speakExercise(
        const Exercise(
          id: 'next',
          type: ExerciseType.speaking,
          prompt: '',
          sentence: 'I need a pen.',
          answer: 'I need a pen.',
          options: [],
        ),
      );
      await tester.pump();
      ready.completeError(StateError('cache extraction failed late'));
      await tester.pump();
      await tester.pump();
      expect(await old, false);
      expect(await next, true);
      expect((player.source as AssetSource).path, 'audio/listening/next.mp3');
      expect(player.implicitStarts, isEmpty);
      expect(player.starts.length, 1);
    },
  );
  for (final boundary in [
    'cache',
    'asset',
    'player initialization',
    'source preparation',
    'TTS language',
    'TTS volume',
  ]) {
    test('stop prevents native playback after delayed $boundary', () async {
      final player = ControlledAudioPlayer();
      final tts = ControlledSpeechEngine();
      final assets = ControlledAssets();
      final documents = ControlledDocuments();
      final blocked = Completer<void>();
      switch (boundary) {
        case 'cache':
          documents.waiting = blocked;
          documents.path = 'cached.mp3';
        case 'asset':
          assets.waiting = blocked;
        case 'player initialization':
          player.contextWait = blocked;
        case 'source preparation':
          player.sourceWait = blocked;
        case 'TTS language':
          assets.exists = false;
          tts.languageWait = blocked;
        case 'TTS volume':
          assets.exists = false;
          tts.volumeWait = blocked;
      }
      final service = TtsService(
        player: player,
        tts: tts,
        assets: assets,
        documents: documents,
      );
      final pending = service.speakExercise(cancellationExercise);
      await Future<void>.delayed(Duration.zero);
      await service.stop();
      blocked.complete();
      expect(await pending, false);
      expect(player.starts, isEmpty);
      expect(tts.spoken, isEmpty);
      service.dispose();
    });
  }
  test(
    'new reference supersedes a pending old source without playing either wrong clip',
    () async {
      final player = ControlledAudioPlayer()..sourceWait = Completer<void>();
      final tts = ControlledSpeechEngine();
      final service = TtsService(
        player: player,
        tts: tts,
        assets: ControlledAssets(),
      );
      final old = service.speakExercise(cancellationExercise);
      await Future<void>.delayed(Duration.zero);
      final next = service.speakExercise(
        const Exercise(
          id: 'next',
          type: ExerciseType.speaking,
          prompt: '',
          sentence: 'I need a pen.',
          answer: 'I need a pen.',
          options: [],
        ),
      );
      player.sourceWait!.complete();
      await Future.wait([old, next]);
      expect(player.starts.length, 1);
      expect(
        (player.starts.single as AssetSource).path,
        'audio/listening/next.mp3',
      );
      service.dispose();
    },
  );
  test(
    'dispose prevents a delayed fallback TTS request from starting',
    () async {
      final tts = ControlledSpeechEngine()..languageWait = Completer<void>();
      final player = ControlledAudioPlayer();
      final service = TtsService(
        player: player,
        tts: tts,
        assets: ControlledAssets()..exists = false,
      );
      final pending = service.speakExercise(cancellationExercise);
      await Future<void>.delayed(Duration.zero);
      service.dispose();
      tts.languageWait!.complete();
      expect(await pending, false);
      expect(tts.spoken, isEmpty);
    },
  );
  test(
    'current asset cached and fallback requests retain playback behavior',
    () async {
      for (final kind in ['asset', 'cached', 'TTS']) {
        final player = ControlledAudioPlayer();
        final tts = ControlledSpeechEngine();
        final assets = ControlledAssets()..exists = kind != 'TTS';
        final documents = ControlledDocuments()
          ..path = kind == 'cached' ? 'cache.mp3' : null;
        final service = TtsService(
          player: player,
          tts: tts,
          assets: assets,
          documents: documents,
        );
        expect(await service.speakExercise(cancellationExercise), true);
        if (kind == 'TTS') {
          expect(tts.spoken, ['I am Tom.']);
          expect(player.starts, isEmpty);
        } else {
          expect(player.starts.length, 1);
          expect(tts.spoken, isEmpty);
        }
        service.dispose();
      }
    },
  );
  test('stop cancels a TTS retry before its second native speak', () async {
    final tts = ControlledSpeechEngine()..results.add(0);
    final player = ControlledAudioPlayer();
    final service = TtsService(
      player: player,
      tts: tts,
      assets: ControlledAssets()..exists = false,
    );
    final pending = service.speak('I am Tom.');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await service.stop();
    expect(await pending, false);
    expect(tts.spoken, ['I am Tom.']);
    service.dispose();
  });
  test(
    'stop cancels remote source preparation without reviving fallback',
    () async {
      final player = ControlledAudioPlayer()..sourceWait = Completer<void>();
      final tts = ControlledSpeechEngine();
      final service = TtsService(
        player: player,
        tts: tts,
        assets: ControlledAssets(),
      );
      final pending = service.speakUrlOrText(
        'https://example.com/pronunciation.mp3',
        'I am Tom.',
      );
      await Future<void>.delayed(Duration.zero);
      await service.stop();
      player.sourceWait!.complete();
      await pending;
      expect(player.starts, isEmpty);
      expect(tts.spoken, isEmpty);
      service.dispose();
    },
  );
}
