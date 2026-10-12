import 'package:hive/hive.dart';

import '../models/course_track.dart';
import '../models/learning_language.dart';

/// 账号级偏好（当前学习大类等）
class SettingsStore {
  static const boxName = 'app_settings';

  Box<String> get _box => Hive.box<String>(boxName);

  String _trackKey(String userKey) => '$userKey|track';

  CourseTrack getTrack(String userKey) =>
      CourseTrack.fromId(_box.get(_trackKey(userKey)));

  CourseTrack getLanguageTrack(String userKey, LearningLanguage language) {
    final raw = _box.get('$userKey|track|${language.name}');
    final current = getTrack(userKey);
    final saved = raw == null ? current : CourseTrack.fromId(raw);
    return saved.language == language
        ? saved
        : CourseTrack.values.firstWhere((t) => t.language == language);
  }

  Future<void> setTrack(String userKey, CourseTrack track) => _box.putAll({
    _trackKey(userKey): track.id,
    '$userKey|track|${track.language.name}': track.id,
  });
}
