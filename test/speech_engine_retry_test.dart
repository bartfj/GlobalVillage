import 'package:english_village/features/lesson/widgets/speaking_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retries once when the recognizer is busy or the audio route fails', () {
    expect(speechEngineShouldRetry('error_busy', false, 0), isTrue);
    expect(speechEngineShouldRetry('error_client', false, 0), isTrue);
    expect(speechEngineShouldRetry('error_audio', false, 0), isTrue);
  });

  test('does not retry a missed utterance or a second failure', () {
    expect(speechEngineShouldRetry('error_no_match', false, 0), isFalse);
    expect(speechEngineShouldRetry('error_speech_timeout', false, 0), isFalse);
    expect(speechEngineShouldRetry('error_busy', false, 1), isFalse);
    expect(speechEngineShouldRetry('error_busy', true, 0), isFalse);
  });
}
