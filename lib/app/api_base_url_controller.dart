import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sources/api_base_url.dart';
import '../data/sources/settings_store.dart';

/// 当前在线服务地址。未单独配置时用编译期默认值。
class ApiBaseUrlController extends StateNotifier<String> {
  ApiBaseUrlController(this._settings) : super(_settings.apiBaseUrl);

  final SettingsStore _settings;

  /// [url] 为 null 时恢复默认地址。
  Future<void> apply(String? url) async {
    await _settings.setApiBaseUrl(url);
    state = _settings.apiBaseUrl;
  }

  bool get isCustom => state != kApiBaseUrl;
}
