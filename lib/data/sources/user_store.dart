import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/user.dart';

/// 账号与会话的 Hive 读写封装
class UserStore {
  static const usersBoxName = 'users';
  static const sessionBoxName = 'auth_session';
  static const sessionKey = 'current';

  Box<User> get _users => Hive.box<User>(usersBoxName);
  Box<String> get _session => Hive.box<String>(sessionBoxName);

  User? getUser(String nickname) => _users.get(nickname);

  List<User> get users => _users.values.toList();

  Future<void> putUser(User user) => _users.put(user.nickname, user);

  static const displayKey = 'currentDisplay';
  static const emailKey = 'currentEmail';
  static const phoneKey = 'currentPhone';
  static const createdAtKey = 'currentCreatedAt';
  static const lastLocalKey = 'lastLocal';
  static const dismissedImportsKey = 'dismissedImports';

  /// 当前会话的 userKey（登录=昵称，在线=`online:<accountId>`，游客='guest'），无会话返回 null
  String? get currentSession => _session.get(sessionKey);

  /// 最近一次退出的本地账号，供之后登录在线账号时导入进度
  String? get lastLocalAccount => _session.get(lastLocalKey);

  Set<String> get dismissedImports {
    final raw = _session.get(dismissedImportsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return decoded.whereType<String>().toSet();
  }

  /// 当前会话的显示名（在线账号用），无会话或未设置返回 null
  String? get currentDisplayName => _session.get(displayKey);

  String? get currentEmail => _session.get(emailKey);

  String? get currentPhone => _session.get(phoneKey);

  DateTime? get currentCreatedAt {
    final raw = _session.get(createdAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setSession(String userKey, {String? displayName}) async {
    await _session.put(sessionKey, userKey);
    if (displayName != null) {
      await _session.put(displayKey, displayName);
    } else {
      await _session.delete(displayKey);
    }
    await _session.delete(emailKey);
    await _session.delete(phoneKey);
    await _session.delete(createdAtKey);
  }

  /// 缓存在线账号公开资料。邮箱或手机为空时清掉对应项。
  Future<void> cacheOnlineAccount({
    required String displayName,
    String? email,
    String? phone,
    DateTime? createdAt,
  }) async {
    await _session.put(displayKey, displayName);
    await _putOptional(emailKey, email);
    await _putOptional(phoneKey, phone);
    await _putOptional(createdAtKey, createdAt?.toUtc().toIso8601String());
  }

  Future<void> _putOptional(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _session.delete(key);
    } else {
      await _session.put(key, value);
    }
  }

  Future<void> rememberLocalAccount(String userKey) =>
      _session.put(lastLocalKey, userKey);

  Future<void> clearLastLocalAccount() => _session.delete(lastLocalKey);

  Future<void> dismissImports(Iterable<String> names) async {
    final next = {...dismissedImports, ...names};
    await _session.put(dismissedImportsKey, jsonEncode(next.toList()));
  }

  Future<void> clearSession() async {
    await _session.delete(sessionKey);
    await _session.delete(displayKey);
    await _session.delete(emailKey);
    await _session.delete(phoneKey);
    await _session.delete(createdAtKey);
  }
}
