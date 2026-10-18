import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base_url.dart';

export 'api_base_url.dart' show kApiBaseUrl;

/// 在线账号公开信息。
class OnlineAccount {
  const OnlineAccount({
    required this.accountId,
    this.email,
    this.phone,
    required this.displayName,
    this.createdAt,
  });

  final String accountId;
  final String? email;
  final String? phone;
  final String displayName;
  final DateTime? createdAt;
}

/// 注册/登录成功结果（账号 + 双 token）。
class OnlineAuthResult {
  const OnlineAuthResult({
    required this.account,
    required this.accessToken,
    required this.refreshToken,
  });

  final OnlineAccount account;
  final String accessToken;
  final String refreshToken;
}

/// 云端鉴权请求失败（网络错误或服务端错误码）。
class CloudAuthException implements Exception {
  const CloudAuthException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => 'CloudAuthException($code, $message)';
}

/// 在线账号 API 客户端（见 docs/在线账号功能设计.md §8）。
class CloudAuthApi {
  CloudAuthApi({
    http.Client? client,
    String? baseUrl,
    String Function()? readBaseUrl,
  }) : _client = client ?? http.Client(),
       _fixedBaseUrl = baseUrl,
       _readBaseUrl = readBaseUrl;

  final http.Client _client;
  final String? _fixedBaseUrl;
  final String Function()? _readBaseUrl;

  String get _baseUrl => _fixedBaseUrl ?? _readBaseUrl?.call() ?? kApiBaseUrl;

  Future<OnlineAuthResult> register({
    String? email,
    String? phone,
    required String password,
    String? displayName,
  }) async {
    final body = await _post('/auth/register', {
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'password': password,
      if (displayName != null) 'displayName': displayName,
    });
    return OnlineAuthResult(
      account: _parseAccount(body['account'] as Map<String, dynamic>),
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
    );
  }

  Future<OnlineAuthResult> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final body = await _post('/auth/login', {
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'password': password,
    });
    return OnlineAuthResult(
      account: _parseAccount(body['account'] as Map<String, dynamic>),
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
    );
  }

  /// 用 refresh token 换新 access token。
  Future<String> refreshAccessToken(String refreshToken) async {
    final body = await _post('/auth/refresh', {'refreshToken': refreshToken});
    return body['accessToken'] as String;
  }

  Future<OnlineAccount> fetchMe(String accessToken) async {
    final body = await _send('GET', '/auth/me', accessToken: accessToken);
    return _parseAccount(body['account'] as Map<String, dynamic>);
  }

  Future<OnlineAccount> updateProfile(
    String accessToken,
    String displayName,
  ) async {
    final body = await _send(
      'PATCH',
      '/auth/profile',
      accessToken: accessToken,
      jsonBody: {'displayName': displayName},
    );
    return _parseAccount(body['account'] as Map<String, dynamic>);
  }

  /// 登出（幂等，失败可忽略）。
  Future<void> logout(String refreshToken) async {
    try {
      await _post('/auth/logout', {'refreshToken': refreshToken});
    } on CloudAuthException {
      // 幂等设计：网络失败时仅清除本地 token
    }
  }

  OnlineAccount _parseAccount(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    return OnlineAccount(
      accountId: json['accountId'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      displayName: json['displayName'] as String,
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
    );
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) =>
      _send('POST', path, jsonBody: body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? jsonBody,
    String? accessToken,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .send(
            http.Request(method, Uri.parse('$_baseUrl$path'))
              ..headers.addAll({
                if (jsonBody != null) 'content-type': 'application/json',
                if (accessToken != null) 'authorization': 'Bearer $accessToken',
              })
              ..body = jsonBody == null ? '' : jsonEncode(jsonBody),
          )
          .then(http.Response.fromStream);
    } catch (_) {
      throw const CloudAuthException('网络连接失败，请稍后重试');
    }
    if (response.statusCode == 204) return const {};
    Map<String, dynamic> json;
    try {
      json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw CloudAuthException('服务响应异常', statusCode: response.statusCode);
    }
    if (response.statusCode >= 400) {
      throw CloudAuthException(
        (json['message'] as String?) ?? '请求失败',
        statusCode: response.statusCode,
        code: json['code'] as String?,
      );
    }
    return json;
  }
}
