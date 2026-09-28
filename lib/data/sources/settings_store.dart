import 'package:hive/hive.dart';

import '../models/course_track.dart';

/// 账号级偏好（当前学习大类等）
class SettingsStore {
  static const boxName = 'app_settings';

  Box<String> get _box => Hive.box<String>(boxName);

  String _trackKey(String userKey) => '$userKey|track';

  CourseTrack getTrack(String userKey) =>
      CourseTrack.fromId(_box.get(_trackKey(userKey)));

  Future<void> setTrack(String userKey, CourseTrack track) =>
      _box.put(_trackKey(userKey), track.id);
}
