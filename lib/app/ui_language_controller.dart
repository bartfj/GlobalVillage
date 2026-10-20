import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sources/settings_store.dart';
import 'app_strings.dart';

/// 界面语言覆盖设置。null 表示自动（跟随当前课程的解释语言）。
class UiLanguageController extends StateNotifier<UiLanguage?> {
  UiLanguageController(this._settings)
    : super(_parse(_settings.uiLanguageOverride));

  final SettingsStore _settings;

  static UiLanguage? _parse(String? raw) {
    switch (raw) {
      case 'chinese':
        return UiLanguage.chinese;
      case 'english':
        return UiLanguage.english;
    }
    return null;
  }

  /// [value] 为 null 时恢复自动。
  Future<void> apply(UiLanguage? value) async {
    await _settings.setUiLanguageOverride(value?.name);
    state = value;
  }

  /// 是否已就英文界面建议询问过用户（只问一次）。
  bool get prompted => _settings.uiLanguagePrompted;

  Future<void> markPrompted() => _settings.setUiLanguagePrompted();
}
