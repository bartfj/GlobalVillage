import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user.dart';
import '../data/repositories/user_repository.dart';
import '../data/sources/cloud_auth_api.dart';
import '../data/sources/progress_store.dart';
import '../data/sources/reward_store.dart';
import '../data/sources/token_store.dart';

/// 会话类型：无会话 / 游客 / 本地账号 / 在线账号
enum AuthMode { none, guest, local, online }

/// 认证状态
class AuthState {
  /// 当前会话的 userKey（本地登录=昵称，在线=`online:<accountId>`，游客='guest'），无会话为 null
  final String? userKey;

  /// 在线会话的 access token（内存态，重启后经 refresh token 重新换取）
  final String? accessToken;

  /// 在线账号的昵称
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

  /// 可选的在线会话就绪通知；应用同步由根 widget 监听会话变化触发。
  /// [refreshAccessToken] 不再回调，避免同步过程中换 token 时重入。
  final void Function()? onOnlineSessionReady;

  /// 丢弃过期的资料请求，避免打开页面时的拉取盖住刚保存的昵称。
  int _profileRequest = 0;
  int _sessionEpoch = 0;

  void _invalidateSessionRequests() {
    _sessionEpoch++;
    _profileRequest++;
  }

  /// 本地账号绑定在线后、切换会话之前复制槽位；由 providers 接线
  final Future<void> Function(String fromUserKey, String toUserKey)?
      onBoundToOnline;

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

  /// 用安全存储的 refresh token 换取新 access token；成功返回 true。
  /// 不触发同步，供同步过程中的 401 重试使用。
  Future<bool> refreshAccessToken() =>
      _refreshOnlineSession(notifyReady: false);

  /// 在线会话重启后静默换取新 access token（断网或 token 失效时保持已登录状态）。
  /// 冷启动成功时通知同步；由同步服务主动调用时不再通知。
  Future<bool> _refreshOnlineSession({bool notifyReady = true}) async {
    final session = state.userKey;
    final epoch = _sessionEpoch;
    if (session == null || !session.startsWith(AuthState.onlineKeyPrefix)) {
      return false;
    }
    try {
      final refreshToken = await _tokenStore.readRefreshToken();
      if (refreshToken == null ||
          !mounted ||
          epoch != _sessionEpoch ||
          state.userKey != session) {
        return false;
      }
      final accessToken = await _cloudAuth.refreshAccessToken(refreshToken);
      if (!mounted || epoch != _sessionEpoch || state.userKey != session) {
        return false;
      }
      state = AuthState(
        userKey: session,
        accessToken: accessToken,
        displayName: state.displayName,
        pendingImportFrom: state.pendingImportFrom,
      );
      if (notifyReady && state.pendingImportFrom == null) {
        onOnlineSessionReady?.call();
      }
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
      _invalidateSessionRequests();
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
      _invalidateSessionRequests();
      state = AuthState(userKey: nickname.trim());
    }
    return error;
  }

  /// 在线注册（邮箱或手机号），成功返回 null，失败返回错误文案
  Future<String?> registerOnline({
    String? email,
    String? phone,
    required String displayName,
    required String password,
    required String confirm,
  }) async {
    if ((email == null || email.isEmpty) && (phone == null || phone.isEmpty)) {
      return '请输入邮箱或手机号';
    }
    final nicknameError = _displayNameError(displayName);
    if (nicknameError != null) return nicknameError;
    if (password.length < 6) return '密码至少 6 位';
    if (password != confirm) return '两次输入的密码不一致';
    try {
      final result = await _cloudAuth.register(
        email: email,
        phone: phone,
        password: password,
        displayName: displayName.trim(),
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

  Future<void> _applyOnlineSession(
    OnlineAuthResult result, {
    bool adoptDeviceAccount = true,
  }) async {
    // 游客或刚退出的本地账号：有进度则等用户确认后再同步，避免先把空槽位上传
    final importFrom =
        adoptDeviceAccount ? _deviceImportSource(result.account.accountId) : null;
    _invalidateSessionRequests();
    await _tokenStore.writeRefreshToken(result.refreshToken);
    await repository.store.setSession(
      '${AuthState.onlineKeyPrefix}${result.account.accountId}',
      displayName: result.account.displayName,
    );
    await repository.store.cacheOnlineAccount(
      displayName: result.account.displayName,
      email: result.account.email,
      phone: result.account.phone,
      createdAt: result.account.createdAt,
    );
    state = AuthState(
      userKey: '${AuthState.onlineKeyPrefix}${result.account.accountId}',
      accessToken: result.accessToken,
      displayName: result.account.displayName,
      pendingImportFrom: importFrom,
    );
    if (importFrom == null) onOnlineSessionReady?.call();
  }

  /// 本机可导入的进度槽位：当前游客优先，否则本机仍有进度的本地账号。
  /// 已绑定到其他在线账号的不再导入。已绑定到当前账号但在线槽位缺课的仍导入。
  String? _deviceImportSource(String accountId) {
    if (state.isGuest && _slotHasData(UserRepository.guestKey)) {
      return UserRepository.guestKey;
    }
    final locals = localAccountsToImport(accountId: accountId);
    if (locals.isEmpty) return null;
    return locals.first;
  }

  /// 当前在线账号可以合并的本地账号。未登录在线时为空。
  List<String> localAccountsToImport({String? accountId}) {
    final id = accountId ?? _onlineAccountId();
    if (id == null) return [];
    final onlineKey = '${AuthState.onlineKeyPrefix}$id';
    final dismissed = repository.store.dismissedImports;
    final names = <String>[];
    for (final user in repository.store.users) {
      if (dismissed.contains(user.nickname)) continue;
      if (user.onlineAccountId != null && user.onlineAccountId != id) {
        continue;
      }
      if (!_slotHasData(user.nickname)) continue;
      if (user.onlineAccountId == id &&
          !_localAheadOf(user.nickname, onlineKey)) {
        continue;
      }
      names.add(user.nickname);
    }
    names.sort();
    return names;
  }

  List<String> localNicknames() {
    final names = repository.store.users.map((user) => user.nickname).toList();
    names.sort();
    return names;
  }

  Future<String?> resetLocalPassword({
    required String nickname,
    required String password,
    required String confirm,
  }) =>
      repository.resetPassword(
        nickname: nickname,
        password: password,
        confirm: confirm,
      );

  String? _onlineAccountId() {
    final key = state.userKey;
    if (key == null || !key.startsWith(AuthState.onlineKeyPrefix)) return null;
    return key.substring(AuthState.onlineKeyPrefix.length);
  }

  bool _localAheadOf(String localKey, String onlineKey) {
    final local = ProgressStore(userKey: localKey).entries;
    final online = ProgressStore(userKey: onlineKey).entries;
    for (final entry in local.entries) {
      final remote = online[entry.key];
      if (remote == null) return true;
      if (entry.value.completed && !remote.completed) return true;
      if (entry.value.correctCount > remote.correctCount) return true;
    }
    final localRewards = RewardStore(userKey: localKey).attempts;
    final onlineRewards = RewardStore(userKey: onlineKey).attempts;
    for (final attemptId in localRewards.keys) {
      if (!onlineRewards.containsKey(attemptId)) return true;
    }
    return false;
  }

  bool _slotHasData(String userKey) =>
      ProgressStore(userKey: userKey).entries.isNotEmpty ||
      RewardStore(userKey: userKey).attempts.isNotEmpty;

  /// 本地账号「注册并绑定」在线账号（§7.2），成功返回 null
  Future<String?> registerAndBind({
    String? email,
    String? phone,
    required String password,
  }) =>
      _bindOnline(
        () => _cloudAuth.register(
          email: email,
          phone: phone,
          password: password,
          displayName: state.userKey,
        ),
      );

  /// 拉取在线资料并写入会话缓存。离线时保留上次缓存。
  Future<void> refreshProfile() async {
    final token = state.accessToken;
    if (!state.isOnline || token == null) return;
    final request = ++_profileRequest;
    try {
      final account = await _cloudAuth.fetchMe(token);
      if (request != _profileRequest) return;
      await _rememberOnlineAccount(account);
    } on CloudAuthException {
      return;
    }
  }

  /// 修改在线昵称。成功返回 null。
  Future<String?> updateDisplayName(String displayName) async {
    final nicknameError = _displayNameError(displayName);
    if (nicknameError != null) return nicknameError;
    final token = state.accessToken;
    if (!state.isOnline || token == null) return '请先登录在线账号';
    final request = ++_profileRequest;
    try {
      final account = await _cloudAuth.updateProfile(token, displayName.trim());
      if (request != _profileRequest) return null;
      await _rememberOnlineAccount(account);
      return null;
    } on CloudAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> _rememberOnlineAccount(OnlineAccount account) async {
    await repository.store.cacheOnlineAccount(
      displayName: account.displayName,
      email: account.email,
      phone: account.phone,
      createdAt: account.createdAt,
    );
    if (!mounted) return;
    state = AuthState(
      userKey: state.userKey,
      accessToken: state.accessToken,
      displayName: account.displayName,
      pendingImportFrom: state.pendingImportFrom,
    );
  }

  String? _displayNameError(String displayName) {
    final length = displayName.trim().runes.length;
    if (length < 2 || length > 12) return '昵称需为 2-12 个字符';
    return null;
  }

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
      final toUserKey =
          '${AuthState.onlineKeyPrefix}${result.account.accountId}';
      await onBoundToOnline?.call(fromUserKey, toUserKey);
      await _applyOnlineSession(result, adoptDeviceAccount: false);
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
      return null;
    } on CloudAuthException catch (e) {
      return e.message;
    }
  }

  /// 导入确认处理完毕后清除标记。接受本地账号导入时记下已绑定。
  Future<void> finishPendingImport({
    required bool imported,
    List<String> nicknames = const [],
  }) async {
    final names = <String>{...nicknames};
    final from = state.pendingImportFrom;
    if (from != null && from != UserRepository.guestKey) names.add(from);
    names.remove(UserRepository.guestKey);
    if (imported) {
      for (final name in names) {
        await _markLocalBound(name);
      }
    } else if (names.isNotEmpty) {
      await repository.store.dismissImports(names);
    }
    if (names.isNotEmpty) await repository.store.clearLastLocalAccount();
    clearPendingImport();
  }

  Future<void> _markLocalBound(String nickname) async {
    final accountId = state.userKey;
    if (accountId == null ||
        !accountId.startsWith(AuthState.onlineKeyPrefix)) {
      return;
    }
    final localUser = repository.store.getUser(nickname);
    if (localUser == null) return;
    await repository.store.putUser(User(
      nickname: localUser.nickname,
      passwordHash: localUser.passwordHash,
      salt: localUser.salt,
      createdAt: localUser.createdAt,
      onlineAccountId:
          accountId.substring(AuthState.onlineKeyPrefix.length),
      onlineBoundAt: DateTime.now().millisecondsSinceEpoch,
    ));
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
    _invalidateSessionRequests();
    await repository.loginAsGuest();
    state = const AuthState(userKey: UserRepository.guestKey);
  }

  Future<void> logout() async {
    _invalidateSessionRequests();
    final localKey = state.mode == AuthMode.local ? state.userKey : null;
    if (state.isOnline) {
      final refreshToken = await _tokenStore.readRefreshToken();
      if (refreshToken != null) {
        await _cloudAuth.logout(refreshToken);
      }
      await _tokenStore.clear();
    }
    await repository.logout();
    if (localKey != null) {
      await repository.store.rememberLocalAccount(localKey);
    }
    state = const AuthState();
  }

  /// 恢复会话（备份导入后调用）
  Future<void> restoreSession(String userKey) async {
    _invalidateSessionRequests();
    await repository.store.setSession(userKey);
    state = AuthState(userKey: userKey);
  }
}
