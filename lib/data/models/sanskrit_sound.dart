/// 逐字母参考录音。独立于题库，不参与课程判分或解锁。
class SanskritSound {
  const SanskritSound({
    required this.id,
    required this.devanagari,
    required this.iast,
    required this.group,
    required this.description,
    required this.hint,
    required this.url,
    required this.sha256,
    required this.byteLength,
  });

  final String id;
  final String devanagari;
  final String iast;
  final String group;
  final String description;
  final String hint;
  final Uri url;
  final String sha256;
  final int byteLength;

  static const groups = [
    'vowel',
    'velar',
    'palatal',
    'retroflex',
    'dental',
    'labial',
    'other',
  ];

  factory SanskritSound.fromJson(Map<String, dynamic> json) {
    final url = Uri.parse(json['url'] as String);
    final id = json['id'] as String;
    final sha = json['sha256'] as String;
    final size = json['byteLength'] as int;
    final group = json['group'] as String;
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha) ||
        size <= 0 ||
        size > 1024 * 1024 ||
        !groups.contains(group) ||
        url.scheme != 'https' ||
        url.host != 'www.arshavidya.org.uk' ||
        !url.path.startsWith('/a/mp3s/sounds/') ||
        !url.path.endsWith('.mp3') ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment) {
      throw const FormatException('Invalid Sanskrit audio entry');
    }
    return SanskritSound(
      id: id,
      devanagari: json['devanagari'] as String,
      iast: json['iast'] as String,
      group: group,
      description: json['description'] as String,
      hint: json['hint'] as String,
      url: url,
      sha256: sha,
      byteLength: size,
    );
  }
}

class SanskritSoundCatalog {
  const SanskritSoundCatalog({required this.sounds, required this.source});

  final List<SanskritSound> sounds;
  final Map<String, dynamic> source;

  factory SanskritSoundCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported Sanskrit audio catalog');
    }
    final sounds = (json['sounds'] as List)
        .map((e) => SanskritSound.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    if (sounds.isEmpty ||
        sounds.map((s) => s.id).toSet().length != sounds.length) {
      throw const FormatException('Empty or duplicate Sanskrit audio entries');
    }
    return SanskritSoundCatalog(
      sounds: List.unmodifiable(sounds),
      source: Map.unmodifiable((json['source'] as Map).cast<String, dynamic>()),
    );
  }
}
