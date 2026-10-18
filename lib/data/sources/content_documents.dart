import 'dart:convert';

/// 服务器内容包与 App 内置文件的对应关系。
const contentPackAssets = <String, String>{
  'course/zero': 'assets/courses/course_zero.json',
  'course/beginner': 'assets/courses/course_beginner.json',
  'course/intermediate': 'assets/courses/course_intermediate.json',
  'course/chinese': 'assets/courses/course_chinese.json',
  'course/sanskrit': 'assets/courses/course_sanskrit.json',
  'dialogues/units': 'assets/dialogues/unit_dialogues.json',
  'dialogues/application_tasks': 'assets/dialogues/application_tasks.json',
  'practice/pronunciation': 'assets/practice/pronunciation.json',
  'practice/vocabulary': 'assets/practice/vocabulary.json',
  'practice/speaking': 'assets/practice/speaking.json',
  'phonetics/en_ipa': 'assets/phonetics/en_ipa.json',
};

final contentAudioPath = RegExp(
  r'^audio/(listening|dialogues)/[A-Za-z0-9_-]+\.mp3$',
);

/// 已发布内容的本地读取口。没有覆盖时返回 null。
abstract class ContentDocuments {
  Future<String?> packJson(String packId);

  /// 已下载音频的绝对路径。
  Future<String?> audioFilePath(String relativePath);

  Future<void> dropPack(String packId);
}

class EmptyContentDocuments implements ContentDocuments {
  const EmptyContentDocuments();

  @override
  Future<String?> packJson(String packId) async => null;

  @override
  Future<String?> audioFilePath(String relativePath) async => null;

  @override
  Future<void> dropPack(String packId) async {}
}

/// 优先用已发布覆盖。覆盖缺失、不是 JSON 对象，或 [accept] 拒绝时，丢掉缓存并使用内置文本。
Future<String> readOverlaidText({
  ContentDocuments? documents,
  required String packId,
  required Future<String> Function() bundle,
  bool Function(String raw)? accept,
}) async {
  final raw = await documents?.packJson(packId);
  if (raw != null && _usable(raw, accept)) return raw;
  if (raw != null) await documents?.dropPack(packId);
  return bundle();
}

bool _usable(String raw, bool Function(String raw)? accept) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return false;
    return accept?.call(raw) ?? true;
  } catch (_) {
    return false;
  }
}
