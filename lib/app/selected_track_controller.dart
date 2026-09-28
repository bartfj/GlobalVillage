import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/course_track.dart';
import '../data/sources/settings_store.dart';

/// 当前学习大类（按账号持久化，默认初级）
class SelectedTrackController extends StateNotifier<CourseTrack> {
  SelectedTrackController({
    required SettingsStore settings,
    required String? Function() readUserKey,
  }) : _settings = settings,
       _readUserKey = readUserKey,
       super(CourseTrack.beginner) {
    reload();
  }

  final SettingsStore _settings;
  final String? Function() _readUserKey;

  void reload() {
    final userKey = _readUserKey();
    if (userKey == null) {
      state = CourseTrack.beginner;
      return;
    }
    state = _settings.getTrack(userKey);
  }

  Future<void> select(CourseTrack track) async {
    final userKey = _readUserKey();
    if (userKey == null) return;
    await _settings.setTrack(userKey, track);
    state = track;
  }
}
