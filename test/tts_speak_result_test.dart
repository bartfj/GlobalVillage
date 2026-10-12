import 'package:english_village/core/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('speakResultOk accepts platform success codes', () {
    expect(TtsService.speakResultOk(1), isTrue);
    expect(TtsService.speakResultOk(true), isTrue);
    expect(TtsService.speakResultOk(0), isFalse);
    expect(TtsService.speakResultOk(false), isFalse);
    expect(TtsService.speakResultOk(null), isFalse);
  });
}
