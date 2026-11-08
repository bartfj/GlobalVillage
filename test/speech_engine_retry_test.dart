import 'package:english_village/features/lesson/widgets/speaking_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retries once when the recognizer is busy or the audio route fails', () {
    expect(speechEngineShouldRetry('error_busy', false, 0), isTrue);
    expect(speechEngineShouldRetry('error_client', false, 0), isTrue);
    expect(speechEngineShouldRetry('error_audio', false, 0), isTrue);
    // Android marks almost every error permanent; still retry engine glitches.
    expect(speechEngineShouldRetry('error_busy', true, 0), isTrue);
  });

  test('retries empty-session timeout / no_match once before user spoke', () {
    expect(
      speechEngineShouldRetry(
        'error_speech_timeout',
        true,
        0,
        hadWords: false,
      ),
      isTrue,
    );
    expect(
      speechEngineShouldRetry('error_no_match', true, 0, hadWords: false),
      isTrue,
    );
  });

  test('does not retry after words heard or a second failure', () {
    expect(
      speechEngineShouldRetry(
        'error_speech_timeout',
        true,
        0,
        hadWords: true,
      ),
      isFalse,
    );
    expect(speechEngineShouldRetry('error_busy', false, 1), isFalse);
    expect(speechEngineShouldRetry('error_network', true, 0), isFalse);
  });
}
