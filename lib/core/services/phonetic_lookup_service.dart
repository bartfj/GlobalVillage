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

  /// 中文释义
  final String? meaning;
  final String? audioUrl;

  const PhoneticResult({
    required this.word,
    this.ipa,
    this.meaning,
    this.audioUrl,
  });
}

/// 本地 IPA/释义优先，有道联网兜底；网络失败不写入否定缓存
class PhoneticLookupService {
  PhoneticLookupService({
    http.Client? client,
    Map<String, String>? localIpa,
    Map<String, String>? localGloss,
    AssetBundle? assetBundle,
    this.documents,
    this.maxCacheEntries = 200,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _injectedLocal = localIpa,
       _injectedGloss = localGloss,
       _assetBundle = assetBundle ?? rootBundle;

  static const _localAsset = 'assets/phonetics/en_ipa.json';
  static const _localGlossAsset = 'assets/phonetics/en_zh.json';
  static const _youdaoBase = 'https://dict.youdao.com/jsonapi';

  final http.Client _client;
  final bool _ownsClient;
  final Map<String, String>? _injectedLocal;
  final Map<String, String>? _injectedGloss;
  final AssetBundle _assetBundle;
  final ContentDocuments? documents;
  final int maxCacheEntries;

  Map<String, String>? _local;
  Map<String, String>? _gloss;
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
    if (_local != null && _gloss != null) return Future.value();
    return _loadingLocal ??= _loadLocal();
  }

  Future<void> _loadLocal() async {
    final local = _injectedLocal != null
        ? Future.value(Map<String, String>.from(_injectedLocal))
        : _readLocalMap('phonetics/en_ipa', _localAsset);
    final gloss = _injectedGloss != null
        ? Future.value(Map<String, String>.from(_injectedGloss))
        : _readLocalMap('phonetics/en_zh', _localGlossAsset);
    final loaded = await Future.wait([local, gloss]);
    _local = loaded[0];
    _gloss = loaded[1];
  }

  Future<Map<String, String>> _readLocalMap(String packId, String asset) async {
    try {
      final raw = await readOverlaidText(
        documents: documents,
        packId: packId,
        bundle: () => _assetBundle.loadString(asset),
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return {
          for (final e in decoded.entries)
            if (e.value is String) e.key.toLowerCase(): e.value as String,
        };
      }
    } catch (_) {
      // 资源缺失或格式不符时按空表处理，不影响另一种表
    }
    return {};
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
    final localIpa = _local?[key]?.trim();
    final localGloss = _gloss?[key]?.trim();
    final hasIpa = localIpa != null && localIpa.isNotEmpty;
    final hasGloss = localGloss != null && localGloss.isNotEmpty;
    if (hasIpa && hasGloss) {
      final result = PhoneticResult(
        word: key,
        ipa: _wrapIpa(localIpa),
        meaning: localGloss,
      );
      _putCache(key, result);
      return result;
    }

    final remote = await _fetchYoudao(key);
    if (remote.status == _RemoteStatus.hit) {
      final result = PhoneticResult(
        word: key,
        ipa: hasIpa ? _wrapIpa(localIpa) : remote.result?.ipa,
        meaning: hasGloss ? localGloss : remote.result?.meaning,
        audioUrl: remote.result?.audioUrl,
      );
      _putCache(key, result);
      return result;
    }
    if (hasIpa) {
      // 联网失败或远端无词条：先给本地音标，不写否定缓存，下次还能补释义
      return PhoneticResult(word: key, ipa: _wrapIpa(localIpa));
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
    final meaning = _parseMeaning(first);
    if (phone == null && meaning == null) return null;
    return PhoneticResult(
      word: word,
      ipa: phone == null ? null : _wrapIpa(phone),
      meaning: meaning,
    );
  }

  /// 有道 `ec.word[0].trs[].tr[].l.i` 是中文释义，可能为字符串或字符串数组。
  static String? _parseMeaning(Map<String, dynamic> first) {
    final trs = first['trs'];
    if (trs is! List) return null;
    final parts = <String>[];
    for (final item in trs) {
      if (item is! Map) continue;
      final tr = item['tr'];
      if (tr is! List) continue;
      for (final entry in tr) {
        final l = entry is Map ? entry['l'] : null;
        final i = l is Map ? l['i'] : null;
        if (i is String && i.trim().isNotEmpty) {
          parts.add(i.trim());
        } else if (i is List) {
          for (final s in i) {
            if (s is String && s.trim().isNotEmpty) parts.add(s.trim());
          }
        }
      }
    }
    if (parts.isEmpty) return null;
    return _cleanMeaning(parts.join('；'));
  }

  static String? _cleanMeaning(String raw) {
    final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;
    if (text.length > 60) return '${text.substring(0, 60)}…';
    return text;
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
