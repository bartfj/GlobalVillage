import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'accounts_repo.dart';
import 'auth_service.dart';
import 'sync_repo.dart';

/// 构建 /v1/* 路由（auth + sync）。
Handler buildRouter(
  AccountsRepo repo,
  AuthService auth, {
  SyncRepo? syncRepo,
}) {
  final sync = syncRepo ?? InMemorySyncRepo();
  final router = Router();

  // POST /v1/auth/register
  router.post('/v1/auth/register', (Request request) async {
    final body = await _readJson(request);
    if (body == null) return _error(400, 'invalid_body', '请求体必须是 JSON 对象');

    final email = _normalizeEmail(body['email']);
    final phone = _normalizePhone(body['phone']);
    if (email == null && phone == null) {
      return _error(400, 'missing_identifier', 'email 与 phone 至少提供其一');
    }

    final password = body['password'];
    if (password is! String || password.length < 6) {
      return _error(400, 'weak_password', '密码至少 6 位');
    }

    var displayName = (body['displayName'] as String?)?.trim();
    if (displayName == null || displayName.isEmpty) {
      displayName = email != null ? email.split('@').first : '学员';
    }

    final now = DateTime.now().toUtc();
    var account = Account(
      accountId: newAccountId(),
      email: email,
      phone: phone,
      passwordHash: await auth.hashPassword(password),
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
    );
    try {
      account = await repo.create(account);
    } on AccountConflictException catch (e) {
      if (e.field == 'email') {
        return _error(409, 'email_taken', '该邮箱已被注册');
      }
      return _error(409, 'phone_taken', '该手机号已被注册');
    }

    return _json(200, {
      'account': account.toPublicJson(),
      'accessToken': auth.issueAccessToken(account.accountId),
      'refreshToken': auth.issueRefreshToken(account.accountId),
    });
  });

  // POST /v1/auth/login
  router.post('/v1/auth/login', (Request request) async {
    final body = await _readJson(request);
    if (body == null) return _error(400, 'invalid_body', '请求体必须是 JSON 对象');

    final email = _normalizeEmail(body['email']);
    final phone = _normalizePhone(body['phone']);
    if (email == null && phone == null) {
      return _error(400, 'missing_identifier', 'email 与 phone 至少提供其一');
    }
    final password = body['password'];
    if (password is! String || password.isEmpty) {
      return _error(400, 'invalid_body', 'password 必填');
    }

    final account = email != null
        ? await repo.findByEmail(email)
        : await repo.findByPhone(phone!);
    // 账号不存在与密码错误统一 401，避免账号枚举
    if (account == null ||
        !await auth.verifyPassword(password, account.passwordHash)) {
      return _error(401, 'invalid_credentials', '账号不存在或密码错误');
    }

    return _json(200, {
      'account': account.toPublicJson(),
      'accessToken': auth.issueAccessToken(account.accountId),
      'refreshToken': auth.issueRefreshToken(account.accountId),
    });
  });

  // POST /v1/auth/refresh
  router.post('/v1/auth/refresh', (Request request) async {
    final body = await _readJson(request);
    if (body == null) return _error(400, 'invalid_body', '请求体必须是 JSON 对象');

    final refreshToken = body['refreshToken'];
    if (refreshToken is! String || refreshToken.isEmpty) {
      return _error(400, 'invalid_body', 'refreshToken 必填');
    }

    final payload = auth.verify(refreshToken);
    if (payload == null || payload.typ != 'refresh') {
      return _error(401, 'invalid_token', 'refresh token 无效或已过期');
    }
    final account = await repo.findById(payload.accountId);
    if (account == null) {
      return _error(401, 'invalid_token', '账号不存在');
    }

    return _json(200, {
      'accessToken': auth.issueAccessToken(account.accountId),
    });
  });

  // POST /v1/auth/logout
  // 幂等：首版不做服务端作废表，仅客户端清除本地 token。
  router.post('/v1/auth/logout', (Request request) async {
    await request.readAsString();
    return Response(204);
  });

  // GET /v1/sync：拉取最新快照；从未同步返回 204
  router.get('/v1/sync', (Request request) async {
    final accountId = _bearerAccountId(request, auth);
    if (accountId == null) return _unauthorized();
    final record = await sync.get(accountId);
    if (record == null) return Response(204);
    return _json(200, record.toJson());
  });

  // PUT /v1/sync：上传客户端已合并的整包快照（乐观并发：baseClientUpdatedAt 不一致 → 409）
  router.put('/v1/sync', (Request request) async {
    final accountId = _bearerAccountId(request, auth);
    if (accountId == null) return _unauthorized();
    final body = await _readJson(request);
    if (body == null) return _error(400, 'invalid_body', '请求体必须是 JSON 对象');
    final payload = body['payload'];
    final clientUpdatedAt = body['clientUpdatedAt'];
    if (payload is! Map<String, dynamic> || clientUpdatedAt is! int) {
      return _error(400, 'invalid_body', 'payload 与 clientUpdatedAt 必填');
    }
    final base = body['baseClientUpdatedAt'];
    try {
      final record = await sync.put(
        accountId,
        payload,
        clientUpdatedAt,
        baseClientUpdatedAt: base is int ? base : null,
      );
      return _json(200, {
        'clientUpdatedAt': record.clientUpdatedAt,
        'serverUpdatedAt': record.serverUpdatedAt.millisecondsSinceEpoch,
      });
    } on SyncConflictException catch (e) {
      return _json(409, {
        'code': 'sync_conflict',
        'message': '云端快照已更新，请先拉取合并',
        'currentClientUpdatedAt': e.currentClientUpdatedAt,
      });
    }
  });

  return router.call;
}

/// 解析 Bearer access token，无效返回 null。
String? _bearerAccountId(Request request, AuthService auth) {
  final header = request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;
  final payload = auth.verify(header.substring(7));
  if (payload == null || payload.typ != 'access') return null;
  return payload.accountId;
}

Response _unauthorized() => _error(401, 'invalid_token', 'access token 无效或已过期');

Future<Map<String, dynamic>?> _readJson(Request request) async {
  final text = await request.readAsString();
  if (text.isEmpty) return <String, dynamic>{};
  try {
    final value = jsonDecode(text);
    return value is Map<String, dynamic> ? value : null;
  } catch (_) {
    return null;
  }
}

String? _normalizeEmail(Object? value) {
  if (value is! String) return null;
  final email = value.trim().toLowerCase();
  return email.isEmpty ? null : email;
}

String? _normalizePhone(Object? value) {
  if (value is! String) return null;
  final phone = value.trim();
  return phone.isEmpty ? null : phone;
}

Response _json(int status, Map<String, Object?> body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Response _error(int status, String code, String message) =>
    _json(status, {'code': code, 'message': message});
