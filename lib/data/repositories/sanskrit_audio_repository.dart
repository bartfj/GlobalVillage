import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/sanskrit_sound.dart';

/// 安装包内的参考录音。校验后写入应用私有目录，供播放器按文件路径读取。
class SanskritAudioRepository {
  SanskritAudioRepository({required this.root, required this.readBundled});

  final Directory root;
  final Future<List<int>> Function(SanskritSound sound) readBundled;
  final Map<String, Future<String>> _pending = {};

  File _file(SanskritSound sound) =>
      File('${root.path}/${sound.id}_${sound.sha256}.mp3');

  Future<bool> _valid(File file, SanskritSound sound) async {
    if (!await file.exists() || await file.length() != sound.byteLength) {
      return false;
    }
    return sha256.convert(await file.readAsBytes()).toString() == sound.sha256;
  }

  Future<Set<String>> cachedIds(Iterable<SanskritSound> sounds) async {
    final ids = <String>{};
    for (final sound in sounds) {
      if (await _valid(_file(sound), sound)) ids.add(sound.id);
    }
    return ids;
  }

  Future<String> fileFor(SanskritSound sound) async {
    final key = '${sound.id}_${sound.sha256}';
    final current = _pending[key];
    if (current != null) return current;
    final future = _fileFor(sound);
    _pending[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_pending[key], future)) _pending.remove(key);
    }
  }

  Future<String> _fileFor(SanskritSound sound) async {
    final file = _file(sound);
    if (await _valid(file, sound)) return file.path;

    final bytes = await readBundled(sound);
    if (bytes.length != sound.byteLength ||
        sha256.convert(bytes).toString() != sound.sha256) {
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
