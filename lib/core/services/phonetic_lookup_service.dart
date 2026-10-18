import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:http/http.dart' as http;

import '../../data/sources/content_documents.dart';

/// 单词音标查询结果
class PhoneticResult {
  final String word;
  final String? ipa;
  final String? audioUrl;

  const PhoneticResult({required this.word, this.ipa, this.audioUrl});
}

/// 本地 IPA 优先，有道联网兜底；网络失败不写入否定缓存
class PhoneticLookupService {
  PhoneticLookupService({
    http.Client? client,
    Map<String, String>? localIpa,
    AssetBundle? assetBundle,
    this.documents,
    this.maxCacheEntries = 200,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _injectedLocal = localIpa,
       _assetBundle = assetBundle ?? rootBundle;

  static const _localAsset = 'assets/phonetics/en_ipa.json';
  static const _youdaoBase = 'https://dict.youdao.com/jsonapi';

  final http.Client _client;
  final bool _ownsClient;
  final Map<String, String>? _injectedLocal;
  final AssetBundle _assetBundle;
  final ContentDocuments? documents;
  final int maxCacheEntries;

  Map<String, String>? _local;
  Future<void>? _loadingLocal;

  /// 命中结果；`null` 表示「已确认无音标」（仅本地+有道确认后）
  final LinkedHashMap<String, PhoneticResult?> _cache =
      LinkedHashMap<String, PhoneticResult?>();
  final Map<String, Future<PhoneticResult?>> _inflight = {};

  /// 去标点并小写，供查词与缓存 key
  static String normalize(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r"^[^A-Za-z']+|[^A-Za-z']+$"), '')
        .toLowerCase();
    return cleaned;
  }

  /// 是否像可查的英文单词（含字母）
  static bool looksEnglish(String token) => RegExp(r"[A-Za-z]").hasMatch(token);

  Future<void> ensureLocalLoaded() {
    if (_local != null) return Future.value();
    return _loadingLocal ??= _loadLocal();
  }

  Future<void> _loadLocal() async {
    if (_injectedLocal != null) {
      _local = Map<String, String>.from(_injectedLocal);
      return;
    }
    try {
      final raw = await readOverlaidText(
        documents: documents,
        packId: 'phonetics/en_ipa',
        bundle: () => _assetBundle.loadString(_localAsset),
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _local = {
          for (final e in decoded.entries)
            if (e.value is String) e.key.toLowerCase(): e.value as String,
        };
      } else {
        _local = {};
      }
    } catch (_) {
      _local = {};
    }
  }

  Future<PhoneticResult?> lookup(String rawWord) async {
    final key = normalize(rawWord);
    if (key.isEmpty) return null;

    if (_cache.containsKey(key)) {
      final cached = _cache.remove(key);
      _cache[key] = cached;
      return cached;
    }

    final pending = _inflight[key];
    if (pending != null) return pending;

    final future = _resolve(key);
    _inflight[key] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<PhoneticResult?> _resolve(String key) async {
    await ensureLocalLoaded();
    final localIpa = _local?[key];
    if (localIpa != null && localIpa.trim().isNotEmpty) {
      final result = PhoneticResult(word: key, ipa: _wrapIpa(localIpa));
      _putCache(key, result);
      return result;
    }

    final remote = await _fetchYoudao(key);
    if (remote.status == _RemoteStatus.hit) {
      _putCache(key, remote.result);
      return remote.result;
    }
    if (remote.status == _RemoteStatus.confirmedMiss) {
      _putCache(key, null);
      return null;
    }
    // 网络失败：不缓存
    return null;
  }

  Future<({_RemoteStatus status, PhoneticResult? result})> _fetchYoudao(
    String key,
  ) async {
    try {
      final uri = Uri.parse(_youdaoBase).replace(queryParameters: {'q': key});
      final response = await _client
          .get(
            uri,
            headers: {
              'User-Agent': 'Mozilla/5.0 EnglishVillageApp',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        return (status: _RemoteStatus.networkError, result: null);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return (status: _RemoteStatus.confirmedMiss, result: null);
      }
      final parsed = _parseYoudao(key, decoded);
      if (parsed == null) {
        return (status: _RemoteStatus.confirmedMiss, result: null);
      }
      return (status: _RemoteStatus.hit, result: parsed);
    } catch (_) {
      return (status: _RemoteStatus.networkError, result: null);
    }
  }

  PhoneticResult? _parseYoudao(String word, Map<String, dynamic> json) {
    final ec = json['ec'];
    if (ec is! Map<String, dynamic>) return null;
    final wordList = ec['word'];
    if (wordList is! List || wordList.isEmpty) return null;
    final first = wordList.first;
    if (first is! Map<String, dynamic>) return null;
    final us = (first['usphone'] as String?)?.trim();
    final uk = (first['ukphone'] as String?)?.trim();
    final phone = (us != null && us.isNotEmpty)
        ? us
        : (uk != null && uk.isNotEmpty)
        ? uk
        : null;
    if (phone == null) return null;
    return PhoneticResult(word: word, ipa: _wrapIpa(phone));
  }

  static String _wrapIpa(String raw) {
    final t = raw.trim();
    if (t.startsWith('/') && t.endsWith('/')) return t;
    return '/$t/';
  }

  void _putCache(String key, PhoneticResult? value) {
    _cache[key] = value;
    while (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

enum _RemoteStatus { hit, confirmedMiss, networkError }
