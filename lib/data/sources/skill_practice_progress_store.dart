import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/skill_practice_progress.dart';

/// 专项章节进度的 Hive 读写（JSON 字符串，按 userKey 隔离）
class SkillPracticeProgressStore {
  static const boxName = 'skill_practice_progress';

  final String userKey;

  const SkillPracticeProgressStore({required this.userKey});

  Box<String> get _box => Hive.box<String>(boxName);

  String _key(String skill, String chapterId) => '$userKey|$skill|$chapterId';

  SkillPracticeChapterProgress? get(String skill, String chapterId) {
    final raw = _box.get(_key(skill, chapterId));
    if (raw == null) return null;
    try {
      return SkillPracticeChapterProgress.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SkillPracticeChapterProgress progress) => _box.put(
        _key(progress.skill, progress.chapterId),
        jsonEncode(progress.toJson()),
      );

  /// 当前账号下某技能全部章节进度（key 为 chapterId）
  Map<String, SkillPracticeChapterProgress> forSkill(String skill) {
    final prefix = '$userKey|$skill|';
    final out = <String, SkillPracticeChapterProgress>{};
    for (final key in _box.keys.whereType<String>()) {
      if (!key.startsWith(prefix)) continue;
      final chapterId = key.substring(prefix.length);
      final progress = get(skill, chapterId);
      if (progress != null) out[chapterId] = progress;
    }
    return out;
  }
}
