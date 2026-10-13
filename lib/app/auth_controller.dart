import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user.dart';
import '../data/repositories/user_repository.dart';
import '../data/sources/cloud_auth_api.dart';
import '../data/sources/progress_store.dart';
import '../data/sources/token_store.dart';

/// 会话类型：无会话 / 游客 / 本地账号 / 在线账号
enum AuthMode { none, guest, local, online }

/// 认证状态
class AuthState {
  /// 当前会话的 userKey（本地登录=昵称，在线=`online:<accountId>`，游客='guest'），无会话为 null
  final String? userKey;

  /// 在线会话的 access token（内存态，重启后经 refresh token 重新换取）
  final String? accessToken;

  /// 在线账号的显示名（邮箱前缀或注册昵称）
  final String? displayName;

  /// 待确认导入的来源槽位（游客注册/登录在线账号后为 'guest'），处理后置 null
  final String? pendingImportFrom;

  const AuthState({
    this.userKey,
    this.accessToken,
    this.displayName,
    this.pendingImportFrom,
  });

  bool get hasSession => userKey != null;
  bool get isGuest => userKey == UserRepository.guestKey;
  bool get isOnline => userKey?.startsWith(onlineKeyPrefix) ?? false;

  AuthMode get mode => userKey == null
      ? AuthMode.none
      : isGuest
          ? AuthMode.guest
          : isOnline
              ? AuthMode.online
              : AuthMode.local;

  /// 在线会话的 userKey 前缀
  static const onlineKeyPrefix = 'online:';
}

/// 认证状态机：启动时从会话存储恢复，登录/退出时更新
class AuthController extends StateNotifier<AuthState> {
  final UserRepository repository;
  final CloudAuthApi _cloudAuth;
  final TokenStore _tokenStore;

  /// 在线会话就绪（登录/注册/静默刷新成功）后触发同步；由 providers 接线
  final void Function()? onOnlineSessionReady;

  /// 本地账号绑定在线后触发槽位迁移与同步；由 providers 接线
  final Future<void> Function(String fromUserKey)? onBoundToOnline;

  AuthController(
    this.repository, {
    CloudAuthApi? cloudAuth,
    TokenStore? tokenStore,
    this.onOnlineSessionReady,
    this.onBoundToOnline,
  })  : _cloudAuth = cloudAuth ?? CloudAuthApi(),
        _tokenStore = tokenStore ?? SecureTokenStore(),
        super(AuthState(
          userKey: repository.store.currentSession,
          displayName: repository.store.currentDisplayName,
        )) {
    unawaited(_refreshOnlineSession());
  }

  /// 用安全存储的 refresh token 换取新 access token；成功返回 true
  Future<bool> refreshAccessToken() => _refreshOnlineSession();

  /// 在线会话重启后静默换取新 access token（断网或 token 失效时保持已登录状态）
  Future<bool> _refreshOnlineSession() async {
    final session = state.userKey;
    if (session == null || !session.startsWith(AuthState.onlineKeyPrefix)) {
      return false;
    }
    try {
      final refreshToken = await _tokenStore.readRefreshToken();
      if (refreshToken == null) return false;
      final accessToken = await _cloudAuth.refreshAccessToken(refreshToken);
      if (!mounted) return false;
      state = AuthState(
        userKey: session,
        accessToken: accessToken,
        displayName: state.displayName,
      );
      return true;
    } catch (_) {
      // 静默失败：保持本地会话，下次操作时再提示
      return false;
    }
  }

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

  /// 在线注册（邮箱或手机号），成功返回 null，失败返回错误文案
  Future<String?> registerOnline({
    String? email,
    String? phone,
    required String password,
    required String confirm,
  }) async {
    if ((email == null || email.isEmpty) && (phone == null || phone.isEmpty)) {
      return '请输入邮箱或手机号';
    }
    if (password.length < 6) return '密码至少 6 位';
    if (password != confirm) return '两次输入的密码不一致';
    try {
      final result = await _cloudAuth.register(
        email: email,
        phone: phone,
        password: password,
      );
      await _applyOnlineSession(result);
      return null;
    } on CloudAuthException catch (e) {
      return e.message;
    }
  }

  /// 在线登录（邮箱或手机号），成功返回 null，失败返回错误文案
  Future<String?> loginOnline({
    String? email,
    String? phone,
    required String password,
  }) async {
    if ((email == null || email.isEmpty) && (phone == null || phone.isEmpty)) {
      return '请输入邮箱或手机号';
    }
    if (password.isEmpty) return '请输入密码';
    try {
      final result = await _cloudAuth.login(
        email: email,
        phone: phone,
        password: password,
      );
      await _applyOnlineSession(result);
      return null;
    } on CloudAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> _applyOnlineSession(OnlineAuthResult result) async {
    // 游客升级为在线：若有游客进度，标记待确认导入（§7.3）
    final importFrom =
        state.isGuest && ProgressStore(userKey: UserRepository.guestKey).entries.isNotEmpty
            ? UserRepository.guestKey
            : null;
    await _tokenStore.writeRefreshToken(result.refreshToken);
    await repository.store.setSession(
      '${AuthState.onlineKeyPrefix}${result.account.accountId}',
      displayName: result.account.displayName,
    );
    state = AuthState(
      userKey: '${AuthState.onlineKeyPrefix}${result.account.accountId}',
      accessToken: result.accessToken,
      displayName: result.account.displayName,
      pendingImportFrom: importFrom,
    );
    onOnlineSessionReady?.call();
  }

  /// 本地账号「注册并绑定」在线账号（§7.2），成功返回 null
  Future<String?> registerAndBind({
    String? email,
    String? phone,
    required String password,
  }) =>
      _bindOnline(
        () => _cloudAuth.register(email: email, phone: phone, password: password),
      );

  /// 本地账号「登录并绑定」在线账号（§7.2），成功返回 null
  Future<String?> loginAndBind({
    String? email,
    String? phone,
    required String password,
  }) =>
      _bindOnline(
        () => _cloudAuth.login(email: email, phone: phone, password: password),
      );

  Future<String?> _bindOnline(
    Future<OnlineAuthResult> Function() action,
  ) async {
    final fromUserKey = state.userKey;
    if (fromUserKey == null || state.isGuest || state.isOnline) {
      return '仅本地账号可绑定';
    }
    try {
      final result = await action();
      await _applyOnlineSession(result);
      // 标记本地账号已绑定（§4.2）
      final localUser = repository.store.getUser(fromUserKey);
      if (localUser != null) {
        await repository.store.putUser(User(
          nickname: localUser.nickname,
          passwordHash: localUser.passwordHash,
          salt: localUser.salt,
          createdAt: localUser.createdAt,
          onlineAccountId: result.account.accountId,
          onlineBoundAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
      await onBoundToOnline?.call(fromUserKey);
      return null;
    } on CloudAuthException catch (e) {
      return e.message;
    }
  }

  /// 游客导入确认处理完毕后清除标记
  void clearPendingImport() {
    if (state.pendingImportFrom == null) return;
    state = AuthState(
      userKey: state.userKey,
      accessToken: state.accessToken,
      displayName: state.displayName,
    );
  }

  Future<void> loginAsGuest() async {
    await repository.loginAsGuest();
    state = const AuthState(userKey: UserRepository.guestKey);
  }

  Future<void> logout() async {
    if (state.isOnline) {
      final refreshToken = await _tokenStore.readRefreshToken();
      if (refreshToken != null) {
        await _cloudAuth.logout(refreshToken);
      }
      await _tokenStore.clear();
    }
    await repository.logout();
    state = const AuthState();
  }

  /// 恢复会话（备份导入后调用）
  Future<void> restoreSession(String userKey) async {
    await repository.store.setSession(userKey);
    state = AuthState(userKey: userKey);
  }
}
