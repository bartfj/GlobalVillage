import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'accounts_repo.dart';
import 'admin_page.dart';
import 'auth_service.dart';
import 'content_api.dart';
import 'content_repo.dart';
import 'report_repo.dart';
import 'snapshot_merge.dart';
import 'sync_repo.dart';

/// 构建 /v1/* 路由（auth + sync + 已发布学习内容）。[adminToken] 非空时才挂载 /admin。
Handler buildRouter(
  AccountsRepo repo,
  AuthService auth, {
  SyncRepo? syncRepo,
  ReportRepo? reportRepo,
  ContentRepo? contentRepo,
  String? adminToken,
}) {
  final sync = syncRepo ?? InMemorySyncRepo();
  final reports = reportRepo ?? InMemoryReportRepo();
  final content = contentRepo ?? InMemoryContentRepo();
  final router = Router();

  // GET /v1/health：探活（无鉴权）
  router.get('/v1/health', (Request request) async {
    return _json(200, {'ok': true, 'service': 'global_village_server'});
  });

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

    final displayName = _validDisplayName(body['displayName']);
    if (displayName == null) {
      return _error(400, 'invalid_display_name', '昵称需为 2-12 个字符');
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
      'accessToken': auth.issueAccessToken(
        account.accountId,
        credentialVersion: account.credentialVersion,
      ),
      'refreshToken': auth.issueRefreshToken(
        account.accountId,
        credentialVersion: account.credentialVersion,
      ),
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
        !await auth.verifyPassword(password, account.passwordHash) ||
        account.disabledAt != null) {
      return _error(401, 'invalid_credentials', '账号不存在或密码错误');
    }

    return _json(200, {
      'account': account.toPublicJson(),
      'accessToken': auth.issueAccessToken(
        account.accountId,
        credentialVersion: account.credentialVersion,
      ),
      'refreshToken': auth.issueRefreshToken(
        account.accountId,
        credentialVersion: account.credentialVersion,
      ),
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
    if (!_sessionUsable(account, payload)) {
      return _error(401, 'invalid_token', 'refresh token 无效或已过期');
    }

    return _json(200, {
      'accessToken': auth.issueAccessToken(
        account!.accountId,
        credentialVersion: account.credentialVersion,
      ),
    });
  });

  router.get('/v1/auth/me', (Request request) async {
    final account = await _accessAccount(request, repo, auth);
    if (account == null) return _unauthorized();
    return _json(200, {'account': account.toPublicJson()});
  });

  router.patch('/v1/auth/profile', (Request request) async {
    final account = await _accessAccount(request, repo, auth);
    if (account == null) return _unauthorized();
    final body = await _readJson(request);
    if (body == null) return _error(400, 'invalid_body', '请求体必须是 JSON 对象');
    final displayName = _validDisplayName(body['displayName']);
    if (displayName == null) {
      return _error(400, 'invalid_display_name', '昵称需为 2-12 个字符');
    }
    final updated = await repo.updateDisplayName(
      account.accountId,
      displayName,
    );
    if (updated == null) return _error(404, 'not_found', '账号不存在');
    return _json(200, {'account': updated.toPublicJson()});
  });

  // POST /v1/auth/logout
  // 幂等：首版不做服务端作废表，仅客户端清除本地 token。
  router.post('/v1/auth/logout', (Request request) async {
    await request.readAsString();
    return Response(204);
  });

  // GET /v1/sync：拉取最新快照；从未同步返回 204
  router.get('/v1/sync', (Request request) async {
    final account = await _accessAccount(request, repo, auth);
    if (account == null) return _unauthorized();
    final record = await sync.get(account.accountId);
    if (record == null) return Response(204);
    return _json(200, record.toJson());
  });

  // PUT /v1/sync：上传客户端已合并的整包快照（乐观并发：baseClientUpdatedAt 不一致 → 409）
  router.put('/v1/sync', (Request request) async {
    final account = await _accessAccount(request, repo, auth);
    if (account == null) return _unauthorized();
    final accountId = account.accountId;
    final body = await _readJson(request);
    if (body == null) return _error(400, 'invalid_body', '请求体必须是 JSON 对象');
    final payload = body['payload'];
    final clientUpdatedAt = body['clientUpdatedAt'];
    if (payload is! Map<String, dynamic> || clientUpdatedAt is! int) {
      return _error(400, 'invalid_body', 'payload 与 clientUpdatedAt 必填');
    }
    if (!_validSyncProgress(payload['progress'])) {
      return _error(400, 'invalid_body', '同步进度格式不正确');
    }
    final base = body['baseClientUpdatedAt'];
    try {
      final record = await sync.put(
        accountId,
        payload,
        clientUpdatedAt,
        baseClientUpdatedAt: base is int ? base : null,
        device: _readDevice(body['device']),
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

  router.post('/v1/reports', (Request request) async {
    final declared = int.tryParse(request.headers['content-length'] ?? '');
    if (declared != null && declared > maxReportBodyBytes) {
      return _error(413, 'payload_too_large', '请求体过大');
    }
    final text = await request.readAsString();
    if (utf8.encode(text).length > maxReportBodyBytes) {
      return _error(413, 'payload_too_large', '请求体过大');
    }
    Map<String, dynamic>? body;
    try {
      final value = jsonDecode(text);
      if (value is Map<String, dynamic>) body = value;
    } catch (_) {
      body = null;
    }
    if (body == null) return _error(400, 'invalid_body', '请求体必须是 JSON 对象');

    final accountId = await _reportAccountId(request, repo, auth);
    final ClientReport report;
    try {
      report = parseClientReport(body, accountId: accountId);
    } on InvalidReportException {
      return _error(400, 'invalid_body', '报告格式不正确');
    }
    final created = await reports.insert(report);
    return _json(200, {'ok': true, 'duplicate': !created});
  });

  mountPublicContent(router, content);

  final token = adminToken?.trim();
  if (token != null && token.isNotEmpty) {
    _mountAdmin(router, repo, sync, reports, auth, content, token);
  }

  return router.call;
}

void _mountAdmin(
  Router router,
  AccountsRepo repo,
  SyncRepo sync,
  ReportRepo reports,
  AuthService auth,
  ContentRepo content,
  String adminToken,
) {
  router.get('/admin', (Request request) {
    return Response.ok(
      adminPageHtml(),
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  });

  router.get('/admin/api/accounts', (Request request) async {
    if (!_adminAllowed(request, adminToken)) return _adminUnauthorized();
    final summaries = await sync.summaries();
    final accounts = await repo.listAll();
    return _json(200, {
      'accounts': [
        for (final account in accounts)
          _adminAccountJson(account, summaries[account.accountId]),
      ],
    });
  });

  router.get('/admin/api/accounts/<id>', (Request request, String id) async {
    if (!_adminAllowed(request, adminToken)) return _adminUnauthorized();
    final account = await repo.findById(id);
    if (account == null) return _error(404, 'not_found', '账号不存在');
    final record = await sync.get(id);
    return _json(200, {
      'account': _adminAccountJson(account, _summaryOf(record)),
      'clientUpdatedAt': record?.clientUpdatedAt,
      'track': _trackOf(record),
      'rewards': _rewardsOf(record),
      'progress': _groupedProgress(record),
    });
  });

  router.post('/admin/api/accounts/<id>/disable', (
    Request request,
    String id,
  ) async {
    if (!_adminAllowed(request, adminToken)) return _adminUnauthorized();
    final account = await repo.setDisabled(id, DateTime.now().toUtc());
    if (account == null) return _error(404, 'not_found', '账号不存在');
    return _json(200, {
      'account': _adminAccountJson(account, _summaryOf(await sync.get(id))),
    });
  });

  router.post('/admin/api/accounts/<id>/enable', (
    Request request,
    String id,
  ) async {
    if (!_adminAllowed(request, adminToken)) return _adminUnauthorized();
    final account = await repo.setDisabled(id, null);
    if (account == null) return _error(404, 'not_found', '账号不存在');
    return _json(200, {
      'account': _adminAccountJson(account, _summaryOf(await sync.get(id))),
    });
  });

  router.post('/admin/api/accounts/<id>/password', (
    Request request,
    String id,
  ) async {
    if (!_adminAllowed(request, adminToken)) return _adminUnauthorized();
    final body = await _readJson(request);
    final password = body?['password'];
    if (password is! String || password.length < 6) {
      return _error(400, 'weak_password', '密码至少 6 位');
    }
    final existing = await repo.findById(id);
    if (existing == null) return _error(404, 'not_found', '账号不存在');
    final updated = await repo.updatePassword(
      id,
      await auth.hashPassword(password),
    );
    if (updated == null) return _error(404, 'not_found', '账号不存在');
    return _json(200, {
      'accountId': updated.accountId,
      'credentialVersion': updated.credentialVersion,
    });
  });

  router.post('/admin/api/sync', (Request request) async {
    if (!_adminAllowed(request, adminToken)) return _adminUnauthorized();
    final body = await _readJson(request);
    final sourceId = body?['sourceAccountId'];
    final targetId = body?['targetAccountId'];
    if (sourceId is! String ||
        targetId is! String ||
        sourceId.isEmpty ||
        targetId.isEmpty) {
      return _error(
        400,
        'invalid_body',
        'sourceAccountId 与 targetAccountId 必填',
      );
    }
    if (sourceId == targetId) {
      return _error(400, 'same_account', '来源和目标不能是同一个账号');
    }
    final sourceAccount = await repo.findById(sourceId);
    final targetAccount = await repo.findById(targetId);
    if (sourceAccount == null || targetAccount == null) {
      return _error(404, 'not_found', '账号不存在');
    }
    final sourceRecord = await sync.get(sourceId);
    if (sourceRecord == null) {
      return _error(400, 'empty_sync', '来源账号没有可同步的进度');
    }
    final targetRecord = await sync.get(targetId);
    final merged = mergeSnapshots(
      source: sourceRecord.payload,
      target: targetRecord?.payload,
    );
    final clientUpdatedAt = merged['clientUpdatedAt'] as int;
    final saved = await sync.put(targetId, merged, clientUpdatedAt);
    return _json(200, {
      'targetAccountId': targetId,
      'lessonCount': lessonCountOf(merged),
      'clientUpdatedAt': clientUpdatedAt,
      'serverUpdatedAt': saved.serverUpdatedAt.millisecondsSinceEpoch,
    });
  });

  router.get('/admin/api/reports', (Request request) async {
    if (!_adminAllowed(request, adminToken)) return _adminUnauthorized();
    final list = await reports.list();
    return _json(200, {
      'reports': [for (final report in list) report.toListJson()],
    });
  });

  router.get('/admin/api/reports/<id>', (Request request, String id) async {
    if (!_adminAllowed(request, adminToken)) return _adminUnauthorized();
    final report = await reports.get(id);
    if (report == null) return _error(404, 'not_found', '报告不存在');
    return _json(200, {'report': report.toDetailJson()});
  });

  router.delete('/admin/api/accounts/<id>', (Request request, String id) async {
    if (!_adminAllowed(request, adminToken)) return _adminUnauthorized();
    final existing = await repo.findById(id);
    if (existing == null) return _error(404, 'not_found', '账号不存在');
    await sync.delete(id);
    await repo.delete(id);
    return Response(204);
  });

  mountAdminContent(
    router,
    content,
    (request) => _adminAllowed(request, adminToken),
  );
}

bool _adminAllowed(Request request, String adminToken) {
  final header = request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) return false;
  return AuthService.constantTimeStringEquals(header.substring(7), adminToken);
}

Response _adminUnauthorized() => _error(401, 'invalid_token', '管理口令无效');

Map<String, Object?> _adminAccountJson(Account account, SyncSummary? summary) =>
    {
      'accountId': account.accountId,
      'email': account.email,
      'phone': account.phone,
      'displayName': account.displayName,
      'createdAt': account.createdAt.toUtc().toIso8601String(),
      'updatedAt': account.updatedAt.toUtc().toIso8601String(),
      'disabledAt': account.disabledAt?.toUtc().toIso8601String(),
      'credentialVersion': account.credentialVersion,
      'serverUpdatedAt': summary?.serverUpdatedAt.toUtc().toIso8601String(),
      'lessonCount': summary?.lessonCount ?? 0,
      'device': summary?.device,
    };

SyncSummary? _summaryOf(SyncRecord? record) {
  if (record == null) return null;
  return SyncSummary(
    clientUpdatedAt: record.clientUpdatedAt,
    serverUpdatedAt: record.serverUpdatedAt,
    lessonCount: lessonCountOf(record.payload),
    device: record.device,
  );
}

Map<String, Object?> _trackOf(SyncRecord? record) {
  final track = record?.payload['track'];
  if (track is Map) return Map<String, Object?>.from(track);
  return {};
}

Map<String, String> _rewardsOf(SyncRecord? record) {
  final rewards = record?.payload['rewards'];
  if (rewards is! Map) return {};
  return {
    for (final entry in rewards.entries)
      if (entry.value is String) entry.key.toString(): entry.value as String,
  };
}

Map<String, List<Map<String, Object?>>> _groupedProgress(SyncRecord? record) {
  final groups = {
    'english': <Map<String, Object?>>[],
    'sanskrit': <Map<String, Object?>>[],
    'chinese': <Map<String, Object?>>[],
    'other': <Map<String, Object?>>[],
  };
  final progress = record?.payload['progress'];
  if (progress is! Map) return groups;
  for (final entry in progress.entries) {
    final id = entry.key.toString();
    final value = entry.value;
    final map = value is Map ? value : const <String, dynamic>{};
    final item = <String, Object?>{
      'lessonId': id,
      'completed': map['completed'] == true,
      'score': (map['score'] as num?)?.toInt() ?? 0,
      'correctCount': (map['correctCount'] as num?)?.toInt() ?? 0,
      'totalCount': (map['totalCount'] as num?)?.toInt() ?? 0,
      'completedAt': (map['completedAt'] as num?)?.toInt(),
    };
    final group = id.startsWith('sa_')
        ? 'sanskrit'
        : id.startsWith('zh_')
        ? 'chinese'
        : 'english';
    groups[group]!.add(item);
  }
  for (final list in groups.values) {
    list.sort(
      (a, b) => (a['lessonId'] as String).compareTo(b['lessonId'] as String),
    );
  }
  return groups;
}

bool _sessionUsable(Account? account, TokenPayload payload) {
  if (account == null || account.disabledAt != null) return false;
  return payload.credentialVersion == account.credentialVersion;
}

/// 有效 access token 才绑定账号。缺失或无效时仍允许上报，账号留空。
Future<String?> _reportAccountId(
  Request request,
  AccountsRepo repo,
  AuthService auth,
) async {
  final payload = _bearerPayload(request, auth);
  if (payload == null || payload.typ != 'access') return null;
  final account = await repo.findById(payload.accountId);
  if (!_sessionUsable(account, payload)) return null;
  return account!.accountId;
}

Future<Account?> _accessAccount(
  Request request,
  AccountsRepo repo,
  AuthService auth,
) async {
  final payload = _bearerPayload(request, auth);
  if (payload == null || payload.typ != 'access') return null;
  final account = await repo.findById(payload.accountId);
  if (!_sessionUsable(account, payload)) return null;
  return account;
}

/// 解析 Bearer token，无效返回 null。不区分 access / refresh。
TokenPayload? _bearerPayload(Request request, AuthService auth) {
  final header = request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;
  return auth.verify(header.substring(7));
}

Response _unauthorized() => _error(401, 'invalid_token', 'access token 无效或已过期');

/// 兼容缺省字段和旧课号，同时拒绝可注入 HTML 或无法解析的进度。
bool _validSyncProgress(Object? value) {
  if (value == null) return true;
  if (value is! Map) return false;
  final idPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  for (final entry in value.entries) {
    if (entry.key is! String || !idPattern.hasMatch(entry.key as String)) {
      return false;
    }
    final item = entry.value;
    if (item is! Map) return false;
    if (item['completed'] != null && item['completed'] is! bool) return false;
    for (final key in ['score', 'correctCount', 'totalCount', 'completedAt']) {
      if (item[key] != null && item[key] is! int) return false;
    }
  }
  return true;
}

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

/// 只保留后台需要的设备字段，限制长度并丢弃未知键，避免客户端塞入任意 JSON。
Map<String, dynamic>? _readDevice(Object? value) {
  if (value is! Map) return null;
  String? field(String key, int max) {
    final text = value[key];
    if (text is! String) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > max ? trimmed.substring(0, max) : trimmed;
  }

  final platform = field('platform', 24);
  final osVersion = field('osVersion', 120);
  final appVersion = field('appVersion', 32);
  final installId = field('installId', 64);
  final device = <String, dynamic>{
    if (platform != null) 'platform': platform,
    if (osVersion != null) 'osVersion': osVersion,
    if (appVersion != null) 'appVersion': appVersion,
    if (installId != null) 'installId': installId,
  };
  return device.isEmpty ? null : device;
}

/// 去掉首尾空白后按字符数校验。空、过短、过长返回 null。
String? _validDisplayName(Object? value) {
  if (value is! String) return null;
  final name = value.trim();
  final length = name.runes.length;
  if (length < 2 || length > 12) return null;
  return name;
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
