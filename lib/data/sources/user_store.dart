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

  Future<void> putUser(User user) => _users.put(user.nickname, user);

  static const displayKey = 'currentDisplay';

  /// 当前会话的 userKey（登录=昵称，在线=`online:<accountId>`，游客='guest'），无会话返回 null
  String? get currentSession => _session.get(sessionKey);

  /// 当前会话的显示名（在线账号用），无会话或未设置返回 null
  String? get currentDisplayName => _session.get(displayKey);

  Future<void> setSession(String userKey, {String? displayName}) async {
    await _session.put(sessionKey, userKey);
    if (displayName != null) {
      await _session.put(displayKey, displayName);
    } else {
      await _session.delete(displayKey);
    }
  }

  Future<void> clearSession() async {
    await _session.delete(sessionKey);
    await _session.delete(displayKey);
  }
}
