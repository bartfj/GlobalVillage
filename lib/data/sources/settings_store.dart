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
    _trackUpdatedKey(userKey): DateTime.now().millisecondsSinceEpoch.toString(),
  });

  String _trackUpdatedKey(String userKey) => '$userKey|trackUpdatedAt';

  /// 课程轨道本地最后修改时间（毫秒），同步合并参考；从未修改为 0
  int trackUpdatedAt(String userKey) =>
      int.tryParse(_box.get(_trackUpdatedKey(userKey)) ?? '') ?? 0;

  /// 导出课程轨道偏好（同步快照用）
  Map<String, dynamic> exportTrackPrefs(String userKey) => {
    'selected': getTrack(userKey).id,
    'perLanguage': {
      for (final language in LearningLanguage.values)
        language.name: getLanguageTrack(userKey, language).id,
    },
    'updatedAt': trackUpdatedAt(userKey),
  };

  /// 导入课程轨道偏好（同步合并且远端更新时调用）
  Future<void> importTrackPrefs(
    String userKey,
    Map<String, dynamic> prefs,
  ) async {
    final perLanguage = prefs['perLanguage'];
    final writes = <String, String>{};
    if (perLanguage is Map) {
      for (final language in LearningLanguage.values) {
        final raw = perLanguage[language.name];
        if (raw is String) writes['$userKey|track|${language.name}'] = raw;
      }
    }
    final selected = prefs['selected'];
    if (selected is String) writes[_trackKey(userKey)] = selected;
    final updatedAt = prefs['updatedAt'];
    if (updatedAt is int) {
      writes[_trackUpdatedKey(userKey)] = updatedAt.toString();
    }
    if (writes.isNotEmpty) await _box.putAll(writes);
  }

  String _lastSyncKey(String userKey) => '$userKey|lastSyncAt';

  /// 上次同步成功时间（毫秒）；从未同步为 null
  int? lastSyncAt(String userKey) =>
      int.tryParse(_box.get(_lastSyncKey(userKey)) ?? '');

  Future<void> setLastSyncAt(String userKey, int milliseconds) =>
      _box.put(_lastSyncKey(userKey), milliseconds.toString());
}
