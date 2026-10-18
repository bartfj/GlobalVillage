import 'dart:convert';

/// 从来源合并进目标。只描述结果，不写库。
///
/// 进度：两边都保留；完成优先，都完成取高分，同分取较新 completedAt。
/// 奖励：并集，同一 attemptId 以来源为准。
/// 线路：以来源为准；来源没有线路时保留目标。
Map<String, dynamic> mergeSnapshots({
  required Map<String, dynamic>? source,
  required Map<String, dynamic>? target,
}) {
  final from = _copy(source);
  final into = _copy(target);

  final progress = <String, dynamic>{};
  final progressIds = {
    ..._map(into['progress']).keys,
    ..._map(from['progress']).keys,
  };
  for (final id in progressIds) {
    final kept = _map(into['progress'])[id];
    final incoming = _map(from['progress'])[id];
    if (kept is! Map) {
      progress[id] = incoming;
    } else if (incoming is! Map) {
      progress[id] = kept;
    } else {
      progress[id] = _mergeLesson(
        Map<String, dynamic>.from(kept),
        Map<String, dynamic>.from(incoming),
      );
    }
  }

  final sourceTrack = _map(from['track']);
  final now = DateTime.now().millisecondsSinceEpoch;
  return {
    'schemaVersion': 1,
    'clientUpdatedAt': now,
    'progress': progress,
    'rewards': {
      ..._stringMap(_map(into['rewards'])),
      ..._stringMap(_map(from['rewards'])),
    },
    'track': sourceTrack.isEmpty ? _map(into['track']) : sourceTrack,
  };
}

Map<String, dynamic> _mergeLesson(
  Map<String, dynamic> older,
  Map<String, dynamic> newer,
) {
  final olderDone = older['completed'] == true;
  final newerDone = newer['completed'] == true;
  if (olderDone != newerDone) return olderDone ? older : newer;
  if (olderDone) {
    final olderScore = _int(older['score']);
    final newerScore = _int(newer['score']);
    if (olderScore != newerScore) {
      return olderScore > newerScore ? older : newer;
    }
    return _int(older['completedAt']) >= _int(newer['completedAt'])
        ? older
        : newer;
  }
  final olderCorrect = _int(older['correctCount']);
  final newerCorrect = _int(newer['correctCount']);
  if (olderCorrect != newerCorrect) {
    return olderCorrect > newerCorrect ? older : newer;
  }
  return _int(older['totalCount']) >= _int(newer['totalCount']) ? older : newer;
}

Map<String, dynamic> _copy(Map<String, dynamic>? value) {
  if (value == null) return {};
  return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

Map<String, String> _stringMap(Map<String, dynamic> value) => {
  for (final entry in value.entries)
    if (entry.value is String) entry.key: entry.value as String,
};

int _int(Object? value) => value is num ? value.toInt() : 0;
