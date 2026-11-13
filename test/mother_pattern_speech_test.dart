import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
// The record dependency owns this native interface; retain its real semaphore.
// ignore: depend_on_referenced_packages
import 'package:record_platform_interface/record_platform_interface.dart';
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

// Keep DeviceMotherPatternRecorder and record's real semaphore; delay only the
// native cancellation and permission boundaries involved in the status race.
class _ControlledNativeRecorder extends RecordPlatform {
  final cancellation = Completer<void>();
  final cancelledCalled = Completer<void>();
  final permission = Completer<bool>();
  final permissionCalled = Completer<void>();
  final disposed = Completer<void>();
  final pcm = StreamController<Uint8List>.broadcast();
  bool recording = false;
  bool blockCancel = true;

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<void> cancel(String recorderId) async {
    recording = false;
    if (blockCancel) {
      if (!cancelledCalled.isCompleted) cancelledCalled.complete();
      await cancellation.future;
    }
  }

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    if (!permissionCalled.isCompleted) permissionCalled.complete();
    return permission.future;
  }

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    recording = true;
    return pcm.stream;
  }

  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();

  @override
  Future<String?> stop(String recorderId) async {
    recording = false;
    return null;
  }

  @override
  Future<void> dispose(String recorderId) async {
    recording = false;
    if (!disposed.isCompleted) disposed.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
    'older native cancellation keeps newer preparation busy until permission resolves',
    () async {
      final previousPlatform = RecordPlatform.instance;
      final native = _ControlledNativeRecorder();
      RecordPlatform.instance = native;
      final deviceSpeech = MotherPatternSpeech(
        recorder: DeviceMotherPatternRecorder(),
        recognizer: FakePatternRecognizer(),
      );
      final cancellation = deviceSpeech.cancel();
      Future<void>? opening;
      try {
        await native.cancelledCalled.future;
        opening = deviceSpeech.start();
        expect(deviceSpeech.status, MotherPatternSpeechStatus.preparing);
        expect(deviceSpeech.busy, true);
        expect(native.permissionCalled.isCompleted, false);
        native.cancellation.complete();
        await native.permissionCalled.future;
        await cancellation;
        expect(deviceSpeech.status, MotherPatternSpeechStatus.preparing);
        expect(
          deviceSpeech.busy,
          true,
          reason: 'Old cancel must not expose retry during pending permission',
        );
        native.permission.complete(true);
        await opening;
        expect(deviceSpeech.status, MotherPatternSpeechStatus.recording);
        expect(deviceSpeech.busy, true);
        expect(native.recording, true);
        await deviceSpeech.finish();
        expect(deviceSpeech.status, MotherPatternSpeechStatus.empty);
        expect(deviceSpeech.busy, false);
        expect(native.recording, false);
        await deviceSpeech.start();
        expect(deviceSpeech.busy, true);
        native.blockCancel = false;
        await deviceSpeech.cancel();
        expect(deviceSpeech.status, MotherPatternSpeechStatus.idle);
        expect(deviceSpeech.busy, false);
        expect(native.recording, false);
      } finally {
        native.blockCancel = false;
        if (!native.cancellation.isCompleted) native.cancellation.complete();
        if (!native.permission.isCompleted) native.permission.complete(false);
        await cancellation;
        await opening;
        await deviceSpeech.cancel();
        deviceSpeech.dispose();
        await native.disposed.future;
        await native.pcm.close();
        RecordPlatform.instance = previousPlatform;
      }
    },
  );

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
