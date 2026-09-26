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

  /// 当前会话的 userKey（登录=昵称，游客='guest'），无会话返回 null
  String? get currentSession => _session.get(sessionKey);

  Future<void> setSession(String userKey) => _session.put(sessionKey, userKey);

  Future<void> clearSession() => _session.delete(sessionKey);
}
