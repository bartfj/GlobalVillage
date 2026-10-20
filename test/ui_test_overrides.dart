import 'package:english_village/app/app_strings.dart';
import 'package:english_village/app/providers.dart';

/// 测试环境没有打开 Hive 设置盒：界面字符串固定为中文，
/// 避免 stringsProvider 链路访问 SettingsStore 抛 Box not found。
final uiStringsOverride = stringsProvider.overrideWithValue(
  const S(UiLanguage.chinese),
);
