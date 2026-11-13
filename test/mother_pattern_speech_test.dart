import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_speech.dart';

class FakePatternRecorder implements MotherPatternRecorder {
  final stream = StreamController<Uint8List>.broadcast();
  bool permitted = true;
  bool failStart = false;
  bool recording = false;
  Completer<bool>? permission;
  Completer<Stream<Uint8List>>? opening;
  int cancels = 0;
  int stops = 0;
  int disposals = 0;
  final cancelWaiters = <Completer<void>>[];
  @override
  Future<bool> hasPermission() async => permission?.future ?? permitted;
  @override
  Future<Stream<Uint8List>> start() async {
    if (failStart) throw StateError('recorder failure');
    recording = true;
    return opening?.future ?? stream.stream;
  }

  @override
  Future<void> stop() async {
    stops++;
    recording = false;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    recording = false;
    if (cancelWaiters.isNotEmpty) await cancelWaiters.removeAt(0).future;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await stream.close();
  }

  void emit([int sample = 5000, int ms = 100]) {
    final pcm = Uint8List(ms * 32);
    final view = ByteData.sublistView(pcm);
    for (var i = 0; i < pcm.length; i += 2) {
      view.setInt16(i, sample, Endian.little);
    }
    stream.add(pcm);
  }
}

class FakePatternRecognizer implements MotherPatternRecognizer {
  bool ready = true;
  String text = 'I’m Tom.';
  bool fail = false;
  Completer<String>? result;
  final received = <Uint8List>[];
  @override
  Future<bool> ensureReady() async => ready;
  @override
  Future<String> recognize(Uint8List pcm) async {
    received.add(Uint8List.fromList(pcm));
    if (fail) throw StateError('recognition failure');
    return result?.future ?? text;
  }
}

void main() {
  late FakePatternRecorder recorder;
  late FakePatternRecognizer recognizer;
  late MotherPatternSpeech speech;
  setUp(() {
    recorder = FakePatternRecorder();
    recognizer = FakePatternRecognizer();
    speech = MotherPatternSpeech(recorder: recorder, recognizer: recognizer);
  });
  tearDown(() {
    speech.dispose();
  });

  test(
    'PCM reaches offline recognition and preserves raw contraction text',
    () async {
      await speech.start();
      expect(speech.status, MotherPatternSpeechStatus.recording);
      recorder.emit();
      await Future<void>.delayed(Duration.zero);
      await speech.finish();
      expect(speech.transcript, 'I’m Tom.');
      expect(recognizer.received.single.length, 3200);
      expect(recorder.recording, false);
      expect(speech.busy, false);
    },
  );
  test('permission denial supports an explicit retry', () async {
    recorder.permitted = false;
    await speech.start();
    expect(speech.status, MotherPatternSpeechStatus.denied);
    recorder.permitted = true;
    await speech.start();
    expect(speech.status, MotherPatternSpeechStatus.recording);
    await speech.cancel();
  });
  test('empty PCM and empty recognition do not invent a transcript', () async {
    await speech.start();
    await speech.finish();
    expect(speech.status, MotherPatternSpeechStatus.empty);
    expect(recognizer.received, isEmpty);
    recognizer.text = '';
    await speech.start();
    recorder.emit();
    await Future<void>.delayed(Duration.zero);
    await speech.finish();
    expect(speech.status, MotherPatternSpeechStatus.empty);
    expect(speech.transcript, '');
  });
  test(
    'pure silent PCM cannot become a spoken answer from ASR hallucination',
    () async {
      recognizer.text = 'I am Tom.';
      await speech.start();
      recorder.emit(0, 1000);
      await Future<void>.delayed(Duration.zero);
      await speech.finish();
      expect(speech.status, MotherPatternSpeechStatus.empty);
      expect(speech.transcript, '');
      expect(recognizer.received, isEmpty);
    },
  );
  test('recorder and recognizer errors remain retryable', () async {
    recorder.failStart = true;
    await speech.start();
    expect(speech.status, MotherPatternSpeechStatus.error);
    recorder.failStart = false;
    recognizer.fail = true;
    await speech.start();
    recorder.emit();
    await Future<void>.delayed(Duration.zero);
    await speech.finish();
    expect(speech.status, MotherPatternSpeechStatus.error);
    recognizer.fail = false;
    await speech.start();
    await speech.cancel();
    expect(speech.status, MotherPatternSpeechStatus.idle);
  });
  test(
    'cancellation ignores late permission and transcription callbacks',
    () async {
      recorder.permission = Completer<bool>();
      final pending = speech.start();
      await speech.cancel();
      recorder.permission!.complete(true);
      await pending;
      expect(recorder.recording, false);
      recorder.permission = null;
      recognizer.result = Completer<String>();
      await speech.start();
      recorder.emit();
      await Future<void>.delayed(Duration.zero);
      final finishing = speech.finish();
      await Future<void>.delayed(Duration.zero);
      await speech.cancel();
      recognizer.result!.complete('wrong stale words');
      await finishing;
      expect(speech.transcript, '');
      expect(speech.status, MotherPatternSpeechStatus.idle);
    },
  );
  testWidgets(
    'silence finishes PCM after speech and session limit stops no speech',
    (tester) async {
      await speech.start();
      await tester.runAsync(() async {
        recorder.emit();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        recorder.emit(0, 6000);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(speech.status, MotherPatternSpeechStatus.idle);
      expect(speech.transcript, 'I’m Tom.');
      await speech.start();
      await tester.pump(const Duration(seconds: 31));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(speech.status, MotherPatternSpeechStatus.empty);
      expect(recorder.recording, false);
    },
  );
  test(
    'late recorder start is cancelled and disposal releases source',
    () async {
      recorder.opening = Completer<Stream<Uint8List>>();
      final opening = speech.start();
      await Future<void>.delayed(Duration.zero);
      await speech.cancel();
      recorder.opening!.complete(recorder.stream.stream);
      await opening;
      expect(recorder.recording, false);
      expect(speech.status, MotherPatternSpeechStatus.idle);
    },
  );
}
