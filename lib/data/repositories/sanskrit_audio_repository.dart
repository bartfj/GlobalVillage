import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/sanskrit_sound.dart';

/// 原站录音按需下载到应用私有目录；安装包仅携带来源与校验清单。
class SanskritAudioRepository {
  SanskritAudioRepository({required this.root, required this.client});

  final Directory root;
  final http.Client client;
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

    final response = await client
        .send(http.Request('GET', sound.url)..followRedirects = false)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200 ||
        !(response.headers['content-type'] ?? '').toLowerCase().startsWith(
          'audio/',
        ) ||
        (response.contentLength != null &&
            response.contentLength != sound.byteLength)) {
      await response.stream.listen(null).cancel();
      throw const FormatException('Unexpected Sanskrit audio response');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 8),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > sound.byteLength) {
        throw const FormatException('Sanskrit audio exceeds expected size');
      }
    }
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
