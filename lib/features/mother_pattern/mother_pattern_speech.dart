import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../../core/services/offline_asr_service.dart';

abstract interface class MotherPatternRecorder {
  Future<bool> hasPermission();
  Future<Stream<Uint8List>> start();
  Future<void> stop();
  Future<void> cancel();
  Future<void> dispose();
}

abstract interface class MotherPatternRecognizer {
  Future<bool> ensureReady();
  Future<String> recognize(Uint8List pcm);
}

enum MotherPatternSpeechStatus {
  idle,
  preparing,
  recording,
  transcribing,
  denied,
  empty,
  error,
}

class MotherPatternSpeech extends ChangeNotifier {
  MotherPatternSpeech({required this.recorder, required this.recognizer});
  final MotherPatternRecorder recorder;
  final MotherPatternRecognizer recognizer;
  MotherPatternSpeechStatus status = MotherPatternSpeechStatus.idle;
  String transcript = '';
  bool get busy =>
      status == MotherPatternSpeechStatus.preparing ||
      status == MotherPatternSpeechStatus.recording ||
      status == MotherPatternSpeechStatus.transcribing;
  StreamSubscription<Uint8List>? _subscription;
  Timer? _limit;
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  int _generation = 0;
  int _silenceMs = 0;
  bool _heardSpeech = false;
  bool _disposed = false;
  Future<void>? _opening;

  bool _current(int generation) => !_disposed && generation == _generation;
  void _status(MotherPatternSpeechStatus value) {
    if (_disposed) return;
    status = value;
    notifyListeners();
  }

  void _clear() {
    _limit?.cancel();
    _limit = null;
    _pcm.clear();
    _silenceMs = 0;
    _heardSpeech = false;
    transcript = '';
  }

  Future<void> start() async {
    if (_disposed || busy) return;
    final generation = ++_generation;
    _clear();
    _status(MotherPatternSpeechStatus.preparing);
    try {
      if (!await recorder.hasPermission()) {
        if (_current(generation)) _status(MotherPatternSpeechStatus.denied);
        return;
      }
      if (!_current(generation)) return;
      if (!await recognizer.ensureReady()) {
        if (_current(generation)) _status(MotherPatternSpeechStatus.error);
        return;
      }
      if (!_current(generation)) return;
      await _opening;
      if (!_current(generation)) return;
      final completed = Completer<void>();
      _opening = completed.future;
      Stream<Uint8List> stream;
      try {
        stream = await recorder.start();
        if (!_current(generation)) {
          await recorder.cancel();
          return;
        }
      } finally {
        completed.complete();
        _opening = null;
      }
      _subscription = stream.listen(
        (chunk) {
          if (!_current(generation) ||
              status != MotherPatternSpeechStatus.recording) {
            return;
          }
          _pcm.add(chunk);
          final samples = ByteData.sublistView(chunk);
          var loud = false;
          for (var offset = 0; offset + 1 < chunk.length; offset += 2) {
            if (samples.getInt16(offset, Endian.little).abs() > 2000) {
              loud = true;
              break;
            }
          }
          if (loud) {
            _heardSpeech = true;
            _silenceMs = 0;
          } else if (_heardSpeech) {
            _silenceMs += chunk.length * 1000 ~/ 32000;
            if (_silenceMs >= 6000) unawaited(finish());
          }
        },
        onError: (Object error) {
          if (!_current(generation)) return;
          unawaited(_fail(generation));
        },
        onDone: () {
          if (_current(generation)) unawaited(finish());
        },
      );
      _status(MotherPatternSpeechStatus.recording);
      _limit = Timer(const Duration(seconds: 30), () {
        if (_current(generation)) unawaited(finish());
      });
    } catch (_) {
      if (_current(generation)) await _fail(generation);
    }
  }

  Future<void> _fail(int generation) async {
    _limit?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    _clear();
    try {
      await recorder.cancel();
    } catch (_) {}
    if (_current(generation)) _status(MotherPatternSpeechStatus.error);
  }

  Future<void> finish() async {
    if (_disposed || status != MotherPatternSpeechStatus.recording) return;
    final generation = _generation;
    _status(MotherPatternSpeechStatus.transcribing);
    _limit?.cancel();
    _limit = null;
    final bytes = _pcm.takeBytes();
    final heardSpeech = _heardSpeech;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await recorder.stop();
      if (!_current(generation)) return;
      if (bytes.isEmpty || !heardSpeech) {
        _status(MotherPatternSpeechStatus.empty);
        return;
      }
      final text = await recognizer.recognize(bytes);
      if (!_current(generation)) return;
      transcript = text;
      _status(
        text.trim().isEmpty
            ? MotherPatternSpeechStatus.empty
            : MotherPatternSpeechStatus.idle,
      );
    } catch (_) {
      if (_current(generation)) await _fail(generation);
    }
  }

  Future<void> cancel() async {
    ++_generation;
    _clear();
    final cancellation = recorder.cancel().catchError((Object _) {});
    await _subscription?.cancel();
    _subscription = null;
    await cancellation;
    _status(MotherPatternSpeechStatus.idle);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _clear();
    unawaited(_release());
    super.dispose();
  }

  Future<void> _release() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await recorder.cancel();
    } catch (_) {}
    await _opening;
    try {
      await recorder.dispose();
    } catch (_) {}
  }
}

class DeviceMotherPatternRecorder implements MotherPatternRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  @override
  Future<bool> hasPermission() => _recorder.hasPermission();
  @override
  Future<Stream<Uint8List>> start() => _recorder.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ),
  );
  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> cancel() => _recorder.cancel();
  @override
  Future<void> dispose() => _recorder.dispose();
}

class OfflineMotherPatternRecognizer implements MotherPatternRecognizer {
  @override
  Future<bool> ensureReady() => OfflineAsrService.instance.ensureReady();
  @override
  Future<String> recognize(Uint8List pcm) =>
      OfflineAsrService.instance.recognize(pcm);
}
