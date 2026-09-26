import 'package:hive/hive.dart';

import '../models/progress.dart';

/// 学习进度的 Hive 读写封装（按 userKey 隔离）
class ProgressStore {
  static const boxName = 'lesson_progress';

  final String userKey;

  const ProgressStore({required this.userKey});

  Box<LessonProgress> get _box => Hive.box<LessonProgress>(boxName);

  String _key(String lessonId) => '$userKey|$lessonId';

  LessonProgress? get(String lessonId) => _box.get(_key(lessonId));

  Future<void> save(LessonProgress progress) =>
      _box.put(_key(progress.lessonId), progress);

  /// 把旧版（无 userKey 前缀）的进度 key 迁移到游客账号下，幂等
  static Future<void> migrateLegacy() async {
    final box = Hive.box<LessonProgress>(boxName);
    final legacyKeys =
        box.keys.where((k) => k is String && !k.contains('|')).toList();
    for (final key in legacyKeys) {
      await box.put('guest|$key', box.get(key)!);
      await box.delete(key);
    }
  }
}
