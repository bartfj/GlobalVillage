import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../app/auth_controller.dart';
import '../constants.dart';
import 'diagnostic_log.dart';
import '../../data/models/progress.dart';
import '../../data/sources/check_in_store.dart';
import '../../data/sources/cloud_auth_api.dart';
import '../../data/sources/progress_store.dart';
import '../../data/sources/reward_store.dart';
import '../../data/sources/settings_store.dart';
import '../../data/sources/sync_api.dart';

/// 一次同步当前走到哪一步。抽屉用它显示步骤和已等待秒数。
enum SyncPhase {
  idle,
  pulling,
  merging,
  writing,
  pushing,
  synced,
  failed,
  signedOut,
}

class SyncActivity {
  const SyncActivity({this.phase = SyncPhase.idle, this.startedAt});

  final SyncPhase phase;
  final DateTime? startedAt;

  int elapsedSeconds(DateTime now) {
    final start = startedAt;
    if (start == null) return 0;
    final seconds = now.difference(start).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  bool get active =>
      phase == SyncPhase.pulling ||
      phase == SyncPhase.merging ||
      phase == SyncPhase.writing ||
      phase == SyncPhase.pushing;
}

/// 同步快照（schemaVersion=1）：progress / rewards / track / checkInDays。
class SyncSnapshot {
  const SyncSnapshot({
    required this.progress,
    required this.rewards,
    required this.track,
    required this.clientUpdatedAt,
    this.checkInDays = const {},
  });

  /// lessonId → 进度
  final Map<String, LessonProgress> progress;

  /// attemptId → lessonId（或旧版 unitId）
  final Map<String, String> rewards;

  /// {selected, perLanguage, updatedAt}
  final Map<String, dynamic> track;

  /// 已完成打卡的北京时间日期。
  final Set<String> checkInDays;

  final int clientUpdatedAt;

  Map<String, dynamic> toPayload() => {
    'schemaVersion': 1,
    'clientUpdatedAt': clientUpdatedAt,
    'progress': {
      for (final e in progress.entries)
        e.key: {
          'completed': e.value.completed,
          'score': e.value.score,
          'correctCount': e.value.correctCount,
          'totalCount': e.value.totalCount,
          'completedAt': e.value.completedAt?.millisecondsSinceEpoch,
        },
    },
    'rewards': rewards,
    'track': track,
    if (checkInDays.isNotEmpty) 'checkInDays': checkInDays.toList()..sort(),
  };

  static SyncSnapshot fromPayload(Map<String, dynamic> payload) {
    final progress = <String, LessonProgress>{};
    final rawProgress = payload['progress'];
    if (rawProgress is Map) {
      for (final entry in rawProgress.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final lessonId = entry.key as String;
        progress[lessonId] = LessonProgress(
          lessonId: lessonId,
          completed: value['completed'] == true,
          score: (value['score'] as num?)?.toInt() ?? 0,
          correctCount: (value['correctCount'] as num?)?.toInt() ?? 0,
          totalCount: (value['totalCount'] as num?)?.toInt() ?? 0,
          completedAt: value['completedAt'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  (value['completedAt'] as num).toInt(),
                ),
        );
      }
    }
    final rewards = <String, String>{};
    final rawRewards = payload['rewards'];
    if (rawRewards is Map) {
      for (final entry in rawRewards.entries) {
        if (entry.value is String) {
          rewards[entry.key as String] = entry.value as String;
        }
      }
    }
    final track = payload['track'];
    return SyncSnapshot(
      progress: progress,
      rewards: rewards,
      track: track is Map ? Map<String, dynamic>.from(track) : const {},
      clientUpdatedAt: (payload['clientUpdatedAt'] as num?)?.toInt() ?? 0,
      checkInDays: CheckInStore.parseDays(payload['checkInDays']),
    );
  }

  /// 判断快照内容是否相同（不计 clientUpdatedAt）。
  static bool sameContent(SyncSnapshot a, SyncSnapshot b) {
    if (a.progress.length != b.progress.length) return false;
    for (final entry in a.progress.entries) {
      final other = b.progress[entry.key];
      if (other == null || !_sameLesson(entry.value, other)) return false;
    }
    if (a.rewards.length != b.rewards.length) return false;
    for (final entry in a.rewards.entries) {
      if (b.rewards[entry.key] != entry.value) return false;
    }
    return setEquals(a.checkInDays, b.checkInDays) &&
        _sameValue(a.track, b.track);
  }

  static bool _sameLesson(LessonProgress a, LessonProgress b) =>
      a.completed == b.completed &&
      a.score == b.score &&
      a.correctCount == b.correctCount &&
      a.totalCount == b.totalCount &&
      a.completedAt?.millisecondsSinceEpoch ==
          b.completedAt?.millisecondsSinceEpoch;

  static bool _sameValue(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_sameValue(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_sameValue(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}

/// 合并规则（docs/在线账号功能设计.md §6，确定性无弹窗）。
class SyncMerger {
  /// 完成优先；双完成取高分（同分取较新 completedAt）；
  /// 双未完成取正确数较多者。
  static LessonProgress mergeLesson(
    LessonProgress local,
    LessonProgress remote,
  ) {
    if (local.completed != remote.completed) {
      return local.completed ? local : remote;
    }
    if (local.completed) {
      if (local.score != remote.score) {
        return local.score > remote.score ? local : remote;
      }
      final localAt = local.completedAt?.millisecondsSinceEpoch ?? 0;
      final remoteAt = remote.completedAt?.millisecondsSinceEpoch ?? 0;
      return localAt >= remoteAt ? local : remote;
    }
    if (local.correctCount != remote.correctCount) {
      return local.correctCount > remote.correctCount ? local : remote;
    }
    return local.totalCount >= remote.totalCount ? local : remote;
  }

  /// 奖励 attemptId 并集（同 id 保留本地值）。
  static Map<String, String> mergeRewards(
    Map<String, String> local,
    Map<String, String> remote,
  ) => {...remote, ...local};

  /// 轨道取 updatedAt 较新一侧。
  static Map<String, dynamic> mergeTrack(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localAt = (local['updatedAt'] as num?)?.toInt() ?? 0;
    final remoteAt = (remote['updatedAt'] as num?)?.toInt() ?? 0;
    if (localAt == remoteAt) return local.isNotEmpty ? local : remote;
    return localAt > remoteAt ? local : remote;
  }

  static SyncSnapshot merge(SyncSnapshot local, SyncSnapshot remote) {
    final lessonIds = {...local.progress.keys, ...remote.progress.keys};
    return SyncSnapshot(
      progress: {
        for (final id in lessonIds)
          id: local.progress[id] == null
              ? remote.progress[id]!
              : remote.progress[id] == null
              ? local.progress[id]!
              : mergeLesson(local.progress[id]!, remote.progress[id]!),
      },
      rewards: mergeRewards(local.rewards, remote.rewards),
      track: mergeTrack(local.track, remote.track),
      checkInDays: {...local.checkInDays, ...remote.checkInDays},
      clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 进度同步：登录后 pull→merge→push；本地变更防抖上传；前台轮询拉取。
class SyncService {
  SyncService({
    required SyncApi api,
    required SettingsStore settings,
    required AuthState Function() readAuth,
    required Future<bool> Function() refreshAccessToken,
    void Function(SyncActivity activity)? onActivity,
    void Function()? onMerged,
    Duration debounce = const Duration(seconds: 2),
    Duration pollInterval = const Duration(seconds: 15),
  }) : _api = api,
       _settings = settings,
       _readAuth = readAuth,
       _refreshAccessToken = refreshAccessToken,
       _onActivity = onActivity,
       _onMerged = onMerged,
       _debounce = debounce,
       _pollInterval = pollInterval;

  final SyncApi _api;
  final SettingsStore _settings;
  final AuthState Function() _readAuth;
  final Future<bool> Function() _refreshAccessToken;
  final void Function(SyncActivity activity)? _onActivity;
  final void Function()? _onMerged;
  final Duration _debounce;
  final Duration _pollInterval;

  Timer? _debounceTimer;
  Timer? _pollTimer;
  Future<void>? _inFlight;
  bool _followUp = false;
  int _changeEpoch = 0;
  bool _dirty = false;

  bool _canSync() {
    final auth = _readAuth();
    return auth.isOnline &&
        auth.userKey != null &&
        auth.pendingImportFrom == null;
  }

  /// 构建当前账号的本地快照。
  SyncSnapshot buildLocal(String userKey) => SyncSnapshot(
    progress: ProgressStore(userKey: userKey).entries,
    rewards: RewardStore(userKey: userKey).attempts,
    track: _settings.exportTrackPrefs(userKey),
    checkInDays: CheckInStore(userKey: userKey).days,
    clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  );

  /// 上传时附带设备信息，仅供管理后台展示；web 上不读取 [Platform]。
  Future<Map<String, dynamic>> _deviceInfo() async => {
    'platform': kIsWeb ? 'web' : Platform.operatingSystem,
    if (!kIsWeb) 'osVersion': Platform.operatingSystemVersion,
    'appVersion': kAppVersion,
    'installId': await _settings.ensureInstallId(),
  };

  /// 登录后/恢复会话后：拉取 → 合并 → 写本地 → 必要时上传（失败不阻断学习）。
  /// 进行中的同步会串行；本轮期间又有本地变更则结束后再跑一轮。
  Future<void> pullMergePush() {
    if (!_canSync()) return Future<void>.value();
    if (_inFlight != null) {
      _followUp = true;
      return _inFlight!;
    }
    final run = _drain();
    _inFlight = run;
    return run;
  }

  Future<void> _drain() async {
    try {
      while (true) {
        _followUp = false;
        final epoch = _changeEpoch;
        final ok = await _pullMergePushOnce();
        if (!ok) {
          if (_followUp) continue;
          return;
        }
        if (_changeEpoch != epoch || _followUp) continue;
        _dirty = false;
        return;
      }
    } finally {
      _inFlight = null;
      if (_dirty && _followUp && _canSync()) {
        _followUp = false;
        _debounceTimer?.cancel();
        _debounceTimer = Timer(_debounce, () {
          unawaited(flushUpload());
        });
      }
    }
  }

  Future<bool> _pullMergePushOnce() async {
    final auth = _readAuth();
    final userKey = auth.userKey;
    if (!auth.isOnline || userKey == null || auth.pendingImportFrom != null) {
      return true;
    }
    final startedAt = DateTime.now();
    try {
      var token = auth.accessToken;
      token ??= await _refreshAccessToken() ? _readAuth().accessToken : null;
      if (token == null) {
        throw const CloudAuthException('登录已过期', statusCode: 401);
      }
      await _pullMergePushWithToken(
        userKey,
        token,
        allowRetry: true,
        startedAt: startedAt,
      );
      await _settings.setLastSyncAt(
        userKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      _onActivity?.call(const SyncActivity(phase: SyncPhase.synced));
      return true;
    } catch (error, stack) {
      recordDiagnosticError('sync', error, stack);
      final expired =
          error is CloudAuthException &&
          cloudAuthFailureIsSessionExpired(error);
      _onActivity?.call(
        SyncActivity(phase: expired ? SyncPhase.signedOut : SyncPhase.failed),
      );
      return false;
    }
  }

  Future<void> _pullMergePushWithToken(
    String userKey,
    String token, {
    required bool allowRetry,
    required DateTime startedAt,
  }) async {
    void phase(SyncPhase value) {
      _onActivity?.call(SyncActivity(phase: value, startedAt: startedAt));
    }

    final device = await _deviceInfo();
    phase(SyncPhase.pulling);
    final pullWatch = Stopwatch()..start();
    RemoteSnapshot? remote;
    try {
      remote = await _api.pull(token);
    } on CloudAuthException catch (e) {
      if (e.statusCode == 401 && allowRetry && await _refreshAccessToken()) {
        return _pullMergePushWithToken(
          userKey,
          _readAuth().accessToken!,
          allowRetry: false,
          startedAt: startedAt,
        );
      }
      rethrow;
    }
    pullWatch.stop();

    phase(SyncPhase.merging);
    final mergeWatch = Stopwatch()..start();
    final local = buildLocal(userKey);
    final Map<String, dynamic> uploadPayload;
    final int uploadUpdatedAt;
    final int? baseClientUpdatedAt;
    SyncSnapshot? toWrite;
    if (remote == null) {
      uploadPayload = local.toPayload();
      uploadUpdatedAt = local.clientUpdatedAt;
      baseClientUpdatedAt = null;
    } else {
      final remoteSnapshot = SyncSnapshot.fromPayload(remote.payload);
      final merged = SyncMerger.merge(local, remoteSnapshot);
      if (!SyncSnapshot.sameContent(merged, local)) toWrite = merged;
      // 内容没变时仍上报设备并刷新后台的同步时间。版本和快照保持云端原值，避免两台互相改写。
      final contentChanged = !SyncSnapshot.sameContent(merged, remoteSnapshot);
      uploadPayload = contentChanged ? merged.toPayload() : remote.payload;
      uploadUpdatedAt = contentChanged
          ? merged.clientUpdatedAt
          : remote.clientUpdatedAt;
      baseClientUpdatedAt = remote.clientUpdatedAt;
    }
    mergeWatch.stop();

    phase(SyncPhase.writing);
    final writeWatch = Stopwatch()..start();
    if (toWrite != null) await _writeLocal(userKey, toWrite);
    writeWatch.stop();

    final trace = <String, dynamic>{
      'pullMs': pullWatch.elapsedMilliseconds,
      'mergeMs': mergeWatch.elapsedMilliseconds,
      'writeMs': writeWatch.elapsedMilliseconds,
      'pullBytes': remote?.byteLength ?? 0,
    };
    phase(SyncPhase.pushing);
    final pushWatch = Stopwatch()..start();
    final int pushBytes;
    try {
      pushBytes = await _api.push(
        token,
        uploadPayload,
        uploadUpdatedAt,
        baseClientUpdatedAt: baseClientUpdatedAt,
        device: device,
        trace: trace,
      );
    } on CloudAuthException catch (e) {
      if (e.code == 'sync_conflict' && allowRetry) {
        return _pullMergePushWithToken(
          userKey,
          token,
          allowRetry: false,
          startedAt: startedAt,
        );
      }
      rethrow;
    }
    pushWatch.stop();
    try {
      await _api.reportTrace(token, uploadUpdatedAt, {
        ...trace,
        'pushMs': pushWatch.elapsedMilliseconds,
        'pushBytes': pushBytes,
      });
    } catch (_) {
      // 补报失败不改变同步结果。
    }
  }

  /// 把合并结果写回本地 Hive（轨道仅在远端更新时覆盖）。
  Future<void> _writeLocal(String userKey, SyncSnapshot snapshot) async {
    final progressStore = ProgressStore(userKey: userKey);
    for (final progress in snapshot.progress.values) {
      await progressStore.save(progress);
    }
    final rewardStore = RewardStore(userKey: userKey);
    final existing = rewardStore.attempts;
    for (final entry in snapshot.rewards.entries) {
      if (!existing.containsKey(entry.key)) {
        await rewardStore.save(entry.key, entry.value);
      }
    }
    final remoteTrackAt = (snapshot.track['updatedAt'] as num?)?.toInt() ?? 0;
    if (remoteTrackAt > _settings.trackUpdatedAt(userKey)) {
      await _settings.importTrackPrefs(userKey, snapshot.track);
    }
    await CheckInStore(userKey: userKey).mergeDays(snapshot.checkInDays);
    _onMerged?.call();
  }

  /// 本机学习或轨道变更后调用（防抖上传；在线且无待导入时才生效）。
  void scheduleUpload() {
    if (!_canSync()) return;
    _dirty = true;
    _changeEpoch++;
    if (_inFlight != null) {
      _followUp = true;
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      unawaited(flushUpload());
    });
  }

  /// 立即上传尚未发出的本地变更。
  Future<void> flushUpload() async {
    _debounceTimer?.cancel();
    if (!_dirty) return;
    await pullMergePush();
  }

  /// 前台：立刻拉一次，之后按间隔拉取。重复调用会重新计时并再拉一次。
  void startForegroundSync() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_canSync()) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!_canSync()) return;
      unawaited(pullMergePush());
    });
    unawaited(pullMergePush());
  }

  /// 离开前台：停止轮询。[flushPending] 为真时立刻上传未发出的本地变更。
  void stopForegroundSync({bool flushPending = true}) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (flushPending) unawaited(flushUpload());
  }

  /// 槽位复制（绑定升级/游客导入），保留源槽位。
  Future<void> copySlot(String fromUserKey, String toUserKey) async {
    await copyStoredSlot(_settings, fromUserKey, toUserKey);
    _onMerged?.call();
  }

  /// 本地账号尚未切换在线身份时也可迁移，无需创建在线同步服务。
  static Future<void> copyStoredSlot(
    SettingsStore settings,
    String fromUserKey,
    String toUserKey,
  ) async {
    final source = ProgressStore(userKey: fromUserKey).entries;
    final target = ProgressStore(userKey: toUserKey);
    for (final progress in source.values) {
      final existingProgress = target.get(progress.lessonId);
      await target.save(
        existingProgress == null
            ? progress
            : SyncMerger.mergeLesson(progress, existingProgress),
      );
    }
    final sourceRewards = RewardStore(userKey: fromUserKey).attempts;
    final targetRewards = RewardStore(userKey: toUserKey);
    final existing = targetRewards.attempts;
    for (final entry in sourceRewards.entries) {
      if (!existing.containsKey(entry.key)) {
        await targetRewards.save(entry.key, entry.value);
      }
    }
    await CheckInStore(
      userKey: toUserKey,
    ).mergeDays(CheckInStore(userKey: fromUserKey).days);
    await settings.importTrackPrefs(
      toUserKey,
      settings.exportTrackPrefs(fromUserKey),
    );
  }

  /// 账号是否已有可同步的本地数据（游客导入确认前判断）。
  bool hasLocalData(String userKey) =>
      ProgressStore(userKey: userKey).entries.isNotEmpty ||
      RewardStore(userKey: userKey).attempts.isNotEmpty;

  void dispose() {
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
  }
}
