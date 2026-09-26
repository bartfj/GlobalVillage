import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/user.dart';
import '../sources/user_store.dart';

/// 账号仓库：本地注册 / 登录 / 游客 / 退出
class UserRepository {
  final UserStore store;

  const UserRepository({required this.store});

  /// 游客会话的 userKey
  static const guestKey = 'guest';

  /// 注册并立即登录。成功返回 null，失败返回错误文案
  Future<String?> register({
    required String nickname,
    required String password,
    required String confirm,
  }) async {
    final name = nickname.trim();
    final length = name.runes.length;
    if (length < 2 || length > 12) return '昵称需为 2-12 个字符';
    if (name.contains('|')) return '昵称不能包含 "|" 字符';
    if (name.toLowerCase() == guestKey) return '该昵称为系统保留';
    if (store.getUser(name) != null) return '该昵称已被注册';
    if (password.length < 6) return '密码至少 6 位';
    if (password != confirm) return '两次输入的密码不一致';
    final salt = _randomSalt();
    final user = User(
      nickname: name,
      passwordHash: _hash(salt, password),
      salt: salt,
      createdAt: DateTime.now(),
    );
    await store.putUser(user);
    await store.setSession(name);
    return null;
  }

  /// 登录。成功返回 null，失败返回错误文案
  Future<String?> login({
    required String nickname,
    required String password,
  }) async {
    final user = store.getUser(nickname.trim());
    if (user == null) return '该昵称未注册';
    if (user.passwordHash != _hash(user.salt, password)) return '密码错误';
    await store.setSession(user.nickname);
    return null;
  }

  Future<void> loginAsGuest() => store.setSession(guestKey);

  Future<void> logout() => store.clearSession();

  static String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
}
