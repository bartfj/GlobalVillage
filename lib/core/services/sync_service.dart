import 'dart:async';

import '../../app/auth_controller.dart';
import 'diagnostic_log.dart';
import '../../data/models/progress.dart';
import '../../data/sources/cloud_auth_api.dart';
import '../../data/sources/progress_store.dart';
import '../../data/sources/reward_store.dart';
import '../../data/sources/settings_store.dart';
import '../../data/sources/sync_api.dart';

/// 同步状态（抽屉展示用）
enum SyncStatus { idle, syncing, synced, failed }

/// 同步快照（schemaVersion=1）：progress / rewards / track。
class SyncSnapshot {
  const SyncSnapshot({
    required this.progress,
    required this.rewards,
    required this.track,
    required this.clientUpdatedAt,
  });

  /// lessonId → 进度
  final Map<String, LessonProgress> progress;

  /// attemptId → lessonId（或旧版 unitId）
  final Map<String, String> rewards;

  /// {selected, perLanguage, updatedAt}
  final Map<String, dynamic> track;

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
    );
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
      clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 进度同步：登录后 pull→merge→push；本地变更防抖上传（§9）。
class SyncService {
  SyncService({
    required SyncApi api,
    required SettingsStore settings,
    required AuthState Function() readAuth,
    required Future<bool> Function() refreshAccessToken,
    void Function(SyncStatus status)? onStatus,
    void Function()? onMerged,
    Duration debounce = const Duration(seconds: 2),
  }) : _api = api,
       _settings = settings,
       _readAuth = readAuth,
       _refreshAccessToken = refreshAccessToken,
       _onStatus = onStatus,
       _onMerged = onMerged,
       _debounce = debounce;

  final SyncApi _api;
  final SettingsStore _settings;
  final AuthState Function() _readAuth;
  final Future<bool> Function() _refreshAccessToken;
  final void Function(SyncStatus status)? _onStatus;
  final void Function()? _onMerged;
  final Duration _debounce;

  Timer? _debounceTimer;
  bool _applyingRemote = false;
  bool _dirty = false;

  /// 构建当前账号的本地快照。
  SyncSnapshot buildLocal(String userKey) => SyncSnapshot(
    progress: ProgressStore(userKey: userKey).entries,
    rewards: RewardStore(userKey: userKey).attempts,
    track: _settings.exportTrackPrefs(userKey),
    clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  );

  /// 登录后/恢复会话后：拉取 → 合并 → 写本地 → 上传（失败不阻断学习）。
  Future<void> pullMergePush() async {
    final auth = _readAuth();
    final userKey = auth.userKey;
    if (!auth.isOnline || userKey == null) return;
    _onStatus?.call(SyncStatus.syncing);
    try {
      var token = auth.accessToken;
      token ??= await _refreshAccessToken() ? _readAuth().accessToken : null;
      if (token == null) {
        throw const CloudAuthException('登录已过期', statusCode: 401);
      }
      await _pullMergePushWithToken(userKey, token, allowRetry: true);
      _dirty = false;
      await _settings.setLastSyncAt(
        userKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      _onStatus?.call(SyncStatus.synced);
    } catch (error, stack) {
      recordDiagnosticError('sync', error, stack);
      _onStatus?.call(SyncStatus.failed);
    }
  }

  Future<void> _pullMergePushWithToken(
    String userKey,
    String token, {
    required bool allowRetry,
  }) async {
    RemoteSnapshot? remote;
    try {
      remote = await _api.pull(token);
    } on CloudAuthException catch (e) {
      if (e.statusCode == 401 && allowRetry && await _refreshAccessToken()) {
        return _pullMergePushWithToken(
          userKey,
          _readAuth().accessToken!,
          allowRetry: false,
        );
      }
      rethrow;
    }
    final local = buildLocal(userKey);
    if (remote == null) {
      // 云端无快照：首次同步，直接上传本地
      await _api.push(token, local.toPayload(), local.clientUpdatedAt);
      return;
    }
    final remoteSnapshot = SyncSnapshot.fromPayload(remote.payload);
    final merged = SyncMerger.merge(local, remoteSnapshot);
    await _writeLocal(userKey, merged);
    try {
      await _api.push(
        token,
        merged.toPayload(),
        merged.clientUpdatedAt,
        baseClientUpdatedAt: remote.clientUpdatedAt,
      );
    } on CloudAuthException catch (e) {
      if (e.code == 'sync_conflict' && allowRetry) {
        // 云端又被更新：重新拉合并一次
        return _pullMergePushWithToken(userKey, token, allowRetry: false);
      }
      rethrow;
    }
  }

  /// 把合并结果写回本地 Hive（轨道仅在远端更新时覆盖）。
  Future<void> _writeLocal(String userKey, SyncSnapshot snapshot) async {
    _applyingRemote = true;
    try {
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
    } finally {
      _applyingRemote = false;
    }
    _onMerged?.call();
  }

  /// 本地进度/奖励/轨道变更后调用（防抖上传；在线会话才生效）。
  void scheduleUpload() {
    if (_applyingRemote) return;
    if (!(_readAuth().isOnline)) return;
    _dirty = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, flushUpload);
  }

  /// 立即上传（App 回前台/退出时调用）。
  Future<void> flushUpload() async {
    _debounceTimer?.cancel();
    if (!_dirty) return;
    await pullMergePush();
  }

  /// 槽位复制（绑定升级/游客导入）：progress + rewards + track，保留源槽位。
  Future<void> copySlot(String fromUserKey, String toUserKey) async {
    final source = ProgressStore(userKey: fromUserKey).entries;
    final target = ProgressStore(userKey: toUserKey);
    for (final progress in source.values) {
      await target.save(progress);
    }
    final sourceRewards = RewardStore(userKey: fromUserKey).attempts;
    final targetRewards = RewardStore(userKey: toUserKey);
    final existing = targetRewards.attempts;
    for (final entry in sourceRewards.entries) {
      if (!existing.containsKey(entry.key)) {
        await targetRewards.save(entry.key, entry.value);
      }
    }
    await _settings.importTrackPrefs(
      toUserKey,
      _settings.exportTrackPrefs(fromUserKey),
    );
    _onMerged?.call();
  }

  /// 账号是否已有可同步的本地数据（游客导入确认前判断）。
  bool hasLocalData(String userKey) =>
      ProgressStore(userKey: userKey).entries.isNotEmpty ||
      RewardStore(userKey: userKey).attempts.isNotEmpty;

  void dispose() => _debounceTimer?.cancel();
}
