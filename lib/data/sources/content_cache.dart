import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'content_documents.dart';

class _CacheEntry {
  const _CacheEntry(this.revision, this.sha256);

  final int revision;
  final String sha256;

  Map<String, Object?> toJson() => {'revision': revision, 'sha256': sha256};
}

/// 把已发布学习内容缓存在本机。清单拉取失败时保留上次缓存。
class ContentCache implements ContentDocuments {
  ContentCache({
    required Directory root,
    http.Client? client,
    required this.readBaseUrl,
    this.budget = const Duration(seconds: 2),
  }) : _root = root,
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final Directory _root;
  final http.Client _client;
  final bool _ownsClient;
  final String Function() readBaseUrl;
  final Duration budget;

  final _documents = <String, _CacheEntry>{};
  final _files = <String, _CacheEntry>{};
  Future<void> _tail = Future<void>.value();
  bool _indexLoaded = false;

  Future<T> _lock<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  /// [allowNetwork] 为 false 时只读本地缓存，供测试避免打到正在运行的服务。
  Future<void> sync({bool allowNetwork = true}) {
    return _lock(() => _sync(allowNetwork));
  }

  Future<void> close() async {
    if (_ownsClient) _client.close();
  }

  @override
  Future<String?> packJson(String packId) {
    return _lock(() async {
      await _loadIndex();
      final entry = _documents[packId];
      if (entry == null) return null;
      final file = _documentFile(packId);
      if (!await file.exists()) return null;
      return file.readAsString();
    });
  }

  @override
  Future<String?> audioFilePath(String relativePath) {
    return _lock(() async {
      await _loadIndex();
      if (!_files.containsKey(relativePath)) return null;
      if (!contentAudioPath.hasMatch(relativePath)) return null;
      final file = _audioFile(relativePath);
      if (!await file.exists()) return null;
      return file.path;
    });
  }

  @override
  Future<void> dropPack(String packId) {
    return _lock(() async {
      await _loadIndex();
      _documents.remove(packId);
      final file = _documentFile(packId);
      if (await file.exists()) await file.delete();
      await _saveIndex();
    });
  }

  Future<void> _sync(bool allowNetwork) async {
    await _loadIndex();
    if (!allowNetwork) return;

    final deadline = DateTime.now().add(budget);
    final response = await _get('/content/manifest', deadline);
    if (response == null || response.statusCode != 200) return;

    final manifest = _object(utf8.decode(response.bodyBytes));
    if (manifest == null) return;

    final liveDocuments = <String, Map<String, dynamic>>{};
    for (final item in _maps(manifest['documents'])) {
      final id = item['id'];
      if (id is String && contentPackAssets.containsKey(id)) {
        liveDocuments[id] = item;
      }
    }
    for (final id in _documents.keys.toList()) {
      if (liveDocuments.containsKey(id)) continue;
      _documents.remove(id);
      final file = _documentFile(id);
      if (await file.exists()) await file.delete();
    }
    for (final entry in liveDocuments.entries) {
      if (DateTime.now().isAfter(deadline)) break;
      final sha = entry.value['sha256'];
      final revision = entry.value['revision'];
      if (sha is! String || revision is! int) continue;
      final current = _documents[entry.key];
      final file = _documentFile(entry.key);
      if (current?.sha256 == sha && await file.exists()) continue;
      final parts = entry.key.split('/');
      final downloaded = await _get(
        '/content/packs/${parts.first}/${parts.sublist(1).join('/')}',
        deadline,
      );
      if (downloaded == null || downloaded.statusCode != 200) continue;
      if (sha256.convert(downloaded.bodyBytes).toString() != sha) continue;
      if (_object(utf8.decode(downloaded.bodyBytes)) == null) continue;
      await file.parent.create(recursive: true);
      await file.writeAsString(utf8.decode(downloaded.bodyBytes));
      _documents[entry.key] = _CacheEntry(revision, sha);
    }

    final liveFiles = <String, Map<String, dynamic>>{};
    for (final item in _maps(manifest['files'])) {
      final path = item['path'];
      if (path is String && contentAudioPath.hasMatch(path)) {
        liveFiles[path] = item;
      }
    }
    for (final path in _files.keys.toList()) {
      if (liveFiles.containsKey(path)) continue;
      _files.remove(path);
      final file = _audioFile(path);
      if (await file.exists()) await file.delete();
    }
    for (final entry in liveFiles.entries) {
      if (DateTime.now().isAfter(deadline)) break;
      final sha = entry.value['sha256'];
      final revision = entry.value['revision'];
      if (sha is! String || revision is! int) continue;
      final current = _files[entry.key];
      final file = _audioFile(entry.key);
      if (current?.sha256 == sha && await file.exists()) continue;
      final downloaded = await _get('/content/files/${entry.key}', deadline);
      if (downloaded == null || downloaded.statusCode != 200) continue;
      if (sha256.convert(downloaded.bodyBytes).toString() != sha) continue;
      await file.parent.create(recursive: true);
      await file.writeAsBytes(downloaded.bodyBytes);
      _files[entry.key] = _CacheEntry(revision, sha);
    }

    await _saveIndex();
  }

  Future<http.Response?> _get(String path, DateTime deadline) async {
    final left = deadline.difference(DateTime.now());
    if (left <= Duration.zero) return null;
    try {
      return await _client
          .get(Uri.parse('${readBaseUrl()}$path'))
          .timeout(left);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadIndex() async {
    if (_indexLoaded) return;
    _indexLoaded = true;
    final file = File('${_root.path}/index.json');
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;
      _readEntries(decoded['documents'], _documents);
      _readEntries(decoded['files'], _files);
    } catch (_) {
      _documents.clear();
      _files.clear();
    }
  }

  void _readEntries(Object? raw, Map<String, _CacheEntry> target) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final value = entry.value;
      if (entry.key is! String || value is! Map) continue;
      final revision = value['revision'];
      final sha = value['sha256'];
      if (revision is! int || sha is! String) continue;
      target[entry.key as String] = _CacheEntry(revision, sha);
    }
  }

  Future<void> _saveIndex() async {
    await _root.create(recursive: true);
    final file = File('${_root.path}/index.json');
    await file.writeAsString(
      jsonEncode({
        'documents': {
          for (final entry in _documents.entries)
            entry.key: entry.value.toJson(),
        },
        'files': {
          for (final entry in _files.entries) entry.key: entry.value.toJson(),
        },
      }),
    );
  }

  File _documentFile(String packId) =>
      File('${_root.path}/docs/${packId.replaceAll('/', '__')}.json');

  File _audioFile(String relativePath) {
    final file = File('${_root.path}/files/$relativePath');
    final root = Directory('${_root.path}/files').absolute.path;
    final resolved = file.absolute.path;
    if (resolved != root &&
        !resolved.startsWith('$root${Platform.pathSeparator}')) {
      throw ArgumentError('音频路径无效');
    }
    return file;
  }
}

Map<String, dynamic>? _object(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  } catch (_) {
    return null;
  }
}

List<Map<String, dynamic>> _maps(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}
