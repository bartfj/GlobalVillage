import 'audio_clip.dart';

/// 瑜伽课堂术语的本地参考发音。
class YogaTermAudio implements AudioClip {
  const YogaTermAudio({
    required this.id,
    required this.devanagari,
    required this.iast,
    required this.sha256,
    required this.byteLength,
  });

  @override
  final String id;
  final String devanagari;
  final String iast;
  @override
  final String sha256;
  @override
  final int byteLength;

  factory YogaTermAudio.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final sha = json['sha256'] as String;
    final size = json['byteLength'] as int;
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha) ||
        size <= 0 ||
        size > 1024 * 1024) {
      throw const FormatException('Invalid yoga audio entry');
    }
    return YogaTermAudio(
      id: id,
      devanagari: json['devanagari'] as String,
      iast: json['iast'] as String,
      sha256: sha,
      byteLength: size,
    );
  }
}

class YogaTermAudioCatalog {
  const YogaTermAudioCatalog({required this.terms, required this.source});

  final Map<String, YogaTermAudio> terms;
  final Map<String, dynamic> source;

  factory YogaTermAudioCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported yoga audio catalog');
    }
    final terms = (json['terms'] as List)
        .map((e) => YogaTermAudio.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    if (terms.isEmpty ||
        terms.map((t) => t.id).toSet().length != terms.length) {
      throw const FormatException('Empty or duplicate yoga audio entries');
    }
    return YogaTermAudioCatalog(
      terms: Map.unmodifiable({for (final term in terms) term.id: term}),
      source: Map.unmodifiable((json['source'] as Map).cast<String, dynamic>()),
    );
  }
}
