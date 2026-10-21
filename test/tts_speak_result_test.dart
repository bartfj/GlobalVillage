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

  test('languageResultOk accepts Android availability codes', () {
    expect(TtsService.languageResultOk(0), isTrue);
    expect(TtsService.languageResultOk(1), isTrue);
    expect(TtsService.languageResultOk(2), isTrue);
    expect(TtsService.languageResultOk(true), isTrue);
    expect(TtsService.languageResultOk(-1), isFalse);
    expect(TtsService.languageResultOk(-2), isFalse);
    expect(TtsService.languageResultOk(false), isFalse);
    expect(TtsService.languageResultOk(null), isFalse);
  });
}
