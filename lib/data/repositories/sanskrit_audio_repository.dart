import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/audio_clip.dart';

/// 安装包内的参考录音。校验后写入应用私有目录，供播放器按文件路径读取。
class SanskritAudioRepository {
  SanskritAudioRepository({required this.root, required this.readBundled});

  final Directory root;
  final Future<List<int>> Function(AudioClip clip) readBundled;
  final Map<String, Future<String>> _pending = {};

  File _file(AudioClip clip) =>
      File('${root.path}/${clip.id}_${clip.sha256}.mp3');

  Future<bool> _valid(File file, AudioClip clip) async {
    if (!await file.exists() || await file.length() != clip.byteLength) {
      return false;
    }
    return sha256.convert(await file.readAsBytes()).toString() == clip.sha256;
  }

  Future<Set<String>> cachedIds(Iterable<AudioClip> clips) async {
    final ids = <String>{};
    for (final clip in clips) {
      if (await _valid(_file(clip), clip)) ids.add(clip.id);
    }
    return ids;
  }

  Future<String> fileFor(AudioClip clip) async {
    final key = '${clip.id}_${clip.sha256}';
    final current = _pending[key];
    if (current != null) return current;
    final future = _fileFor(clip);
    _pending[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_pending[key], future)) _pending.remove(key);
    }
  }

  Future<String> _fileFor(AudioClip clip) async {
    final file = _file(clip);
    if (await _valid(file, clip)) return file.path;

    final bytes = await readBundled(clip);
    if (bytes.length != clip.byteLength ||
        sha256.convert(bytes).toString() != clip.sha256) {
      throw const FormatException('Sanskrit audio checksum mismatch');
    }

    await root.create(recursive: true);
    final staging = File('${file.path}.part');
    try {
      await staging.writeAsBytes(bytes, flush: true);
      await staging.rename(file.path);
    } finally {
      if (await staging.exists()) await staging.delete();
    }
    return file.path;
  }
}
