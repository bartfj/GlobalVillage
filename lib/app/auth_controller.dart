import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/user_repository.dart';

/// 认证状态
class AuthState {
  /// 当前会话的 userKey（登录=昵称，游客='guest'），无会话为 null
  final String? userKey;

  const AuthState({this.userKey});

  bool get hasSession => userKey != null;
  bool get isGuest => userKey == UserRepository.guestKey;
}

/// 认证状态机：启动时从会话存储恢复，登录/退出时更新
class AuthController extends StateNotifier<AuthState> {
  final UserRepository repository;

  AuthController(this.repository)
      : super(AuthState(userKey: repository.store.currentSession));

  /// 注册并登录，成功返回 null，失败返回错误文案
  Future<String?> register({
    required String nickname,
    required String password,
    required String confirm,
  }) async {
    final error = await repository.register(
      nickname: nickname,
      password: password,
      confirm: confirm,
    );
    if (error == null) {
      state = AuthState(userKey: nickname.trim());
    }
    return error;
  }

  /// 登录，成功返回 null，失败返回错误文案
  Future<String?> login({
    required String nickname,
    required String password,
  }) async {
    final error = await repository.login(
      nickname: nickname,
      password: password,
    );
    if (error == null) {
      state = AuthState(userKey: nickname.trim());
    }
    return error;
  }

  Future<void> loginAsGuest() async {
    await repository.loginAsGuest();
    state = const AuthState(userKey: UserRepository.guestKey);
  }

  Future<void> logout() async {
    await repository.logout();
    state = const AuthState();
  }

  /// 恢复会话（备份导入后调用）
  Future<void> restoreSession(String userKey) async {
    await repository.store.setSession(userKey);
    state = AuthState(userKey: userKey);
  }
}
