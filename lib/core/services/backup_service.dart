import 'dart:convert';

import 'package:hive/hive.dart';

import '../../data/models/progress.dart';
import '../../data/models/user.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/sources/progress_store.dart';
import '../../data/sources/reward_store.dart';
import '../../data/sources/user_store.dart';

/// 账号与进度的备份码导出/导入（离线 JSON，用户自行保管）
class BackupService {
  final UserStore _userStore;

  const BackupService({required UserStore userStore}) : _userStore = userStore;

  /// 导出当前登录账号的备份 JSON；游客或无会话返回 null
  Future<String?> exportBackup() async {
    final userKey = _userStore.currentSession;
    if (userKey == null || userKey == UserRepository.guestKey) return null;
    final user = _userStore.getUser(userKey);
    if (user == null) return null;

    final progressBox = Hive.box<LessonProgress>(ProgressStore.boxName);
    final prefix = '$userKey|';
    final progress = progressBox.keys
        .where((k) => k is String && k.startsWith(prefix))
        .map((k) => progressBox.get(k)!)
        .map(
          (p) => {
            'lessonId': p.lessonId,
            'completed': p.completed,
            'score': p.score,
            'correctCount': p.correctCount,
            'totalCount': p.totalCount,
            'completedAt': p.completedAt?.millisecondsSinceEpoch,
          },
        )
        .toList();

    final rewards = RewardStore(userKey: userKey).attempts.entries
        .map((entry) => {'attemptId': entry.key, 'unitId': entry.value})
        .toList();

    return jsonEncode({
      'version': 2,
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'user': {
        'nickname': user.nickname,
        'passwordHash': user.passwordHash,
        'salt': user.salt,
        'createdAt': user.createdAt.millisecondsSinceEpoch,
      },
      'progress': progress,
      'rewards': rewards,
    });
  }

  /// 导入备份 JSON 并设置会话。成功返回 null，失败返回错误文案
  Future<String?> importBackup(String jsonStr) async {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr.trim()) as Map<String, dynamic>;
    } catch (_) {
      return '备份码格式错误，无法解析';
    }
    if (data['version'] != 1 && data['version'] != 2) return '不支持的备份码版本';
    final userJson = data['user'];
    if (userJson is! Map<String, dynamic> ||
        userJson['nickname'] is! String ||
        userJson['passwordHash'] is! String ||
        userJson['salt'] is! String ||
        userJson['createdAt'] is! int) {
      return '备份码缺少账号信息';
    }
    final nickname = userJson['nickname'] as String;
    if (nickname.isEmpty || nickname == UserRepository.guestKey) {
      return '备份码账号无效';
    }

    final rewardEntries = <String, String>{};
    if (data['version'] == 2) {
      final rewards = data['rewards'];
      if (rewards is! List) return '备份码收藏数据错误';
      for (final item in rewards) {
        if (item is! Map<String, dynamic> ||
            item['attemptId'] is! String ||
            item['unitId'] is! String) {
          return '备份码收藏数据错误';
        }
        final attemptId = item['attemptId'] as String;
        final unitId = item['unitId'] as String;
        if (attemptId.isEmpty ||
            attemptId.contains('|') ||
            !RegExp(r'^u(?:[1-9]|1[0-4])$').hasMatch(unitId) ||
            rewardEntries.containsKey(attemptId)) {
          return '备份码收藏数据错误';
        }
        rewardEntries[attemptId] = unitId;
      }
    }

    final user = User(
      nickname: nickname,
      passwordHash: userJson['passwordHash'] as String,
      salt: userJson['salt'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        userJson['createdAt'] as int,
      ),
    );
    await _userStore.putUser(user);

    final progressBox = Hive.box<LessonProgress>(ProgressStore.boxName);
    final progressList = data['progress'];
    if (progressList is List) {
      for (final item in progressList) {
        if (item is! Map<String, dynamic>) continue;
        final lessonId = item['lessonId'];
        if (lessonId is! String) continue;
        await progressBox.put(
          '$nickname|$lessonId',
          LessonProgress(
            lessonId: lessonId,
            completed: item['completed'] == true,
            score: (item['score'] as num?)?.toInt() ?? 0,
            correctCount: (item['correctCount'] as num?)?.toInt() ?? 0,
            totalCount: (item['totalCount'] as num?)?.toInt() ?? 0,
            completedAt: item['completedAt'] is int
                ? DateTime.fromMillisecondsSinceEpoch(
                    item['completedAt'] as int,
                  )
                : null,
          ),
        );
      }
    }

    final rewardStore = RewardStore(userKey: nickname);
    for (final entry in rewardEntries.entries) {
      if (rewardStore.get(entry.key) == null) {
        await rewardStore.save(entry.key, entry.value);
      }
    }

    await _userStore.setSession(nickname);
    return null;
  }
}
