import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../data/sources/mother_pattern_store.dart';
import 'mother_pattern_speech.dart';

final motherPatternStoreProvider = Provider<MotherPatternStore?>((ref) {
  final learning = ref.watch(learningStoreProvider);
  return learning == null
      ? null
      : MotherPatternStore(userKey: learning.userKey, learningStore: learning);
});
final motherPatternSpeechFactoryProvider =
    Provider<MotherPatternSpeech Function()>(
      (ref) =>
          () => MotherPatternSpeech(
            recorder: DeviceMotherPatternRecorder(),
            recognizer: OfflineMotherPatternRecognizer(),
          ),
    );
