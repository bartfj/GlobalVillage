import 'package:audioplayers/audioplayers.dart';

/// 答题反馈音效（正确 / 错误）
class SoundService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playCorrect() => _play('sounds/correct.wav');

  Future<void> playWrong() => _play('sounds/wrong.wav');

  Future<void> _play(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {
      // 音效播放失败不影响答题流程
    }
  }

  void dispose() => _player.dispose();
}
