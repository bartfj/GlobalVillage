import 'dart:math';

import 'package:hive/hive.dart';

import '../models/course_track.dart';
import '../models/learning_language.dart';
import 'api_base_url.dart';

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

  static const _installIdKey = 'installId';

  /// 本机安装标识。首次调用时生成并写入设置，之后保持不变。
  Future<String> ensureInstallId() async {
    final saved = _box.get(_installIdKey);
    if (saved != null && saved.isNotEmpty) return saved;
    final random = Random.secure();
    final id = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _box.put(_installIdKey, id);
    return id;
  }

  static const _apiBaseUrlKey = 'apiBaseUrl';

  /// 当前在线服务地址。未配置时用编译期 [kApiBaseUrl]。
  String get apiBaseUrl {
    final saved = _box.get(_apiBaseUrlKey);
    if (saved == null || saved.isEmpty) return kApiBaseUrl;
    return saved;
  }

  /// [url] 为空时清除自定义地址，改回编译期默认值。
  Future<void> setApiBaseUrl(String? url) {
    if (url == null || url.isEmpty || url == kApiBaseUrl) {
      return _box.delete(_apiBaseUrlKey);
    }
    return _box.put(_apiBaseUrlKey, url);
  }

  static const _uiLanguageKey = 'uiLanguage';
  static const _uiLanguagePromptedKey = 'uiLanguagePrompted';

  /// 界面语言覆盖：'chinese' / 'english'；null 表示跟随解释语言自动决定。
  String? get uiLanguageOverride {
    final saved = _box.get(_uiLanguageKey);
    if (saved == 'chinese' || saved == 'english') return saved;
    return null;
  }

  /// [value] 为空时清除覆盖，恢复跟随解释语言。
  Future<void> setUiLanguageOverride(String? value) {
    if (value == null) return _box.delete(_uiLanguageKey);
    return _box.put(_uiLanguageKey, value);
  }

  /// 是否已就"切换到英文界面"询问过用户（只问一次）。
  bool get uiLanguagePrompted => _box.get(_uiLanguagePromptedKey) == '1';

  Future<void> setUiLanguagePrompted() =>
      _box.put(_uiLanguagePromptedKey, '1');
}
