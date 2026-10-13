import 'dart:convert';

import 'package:http/http.dart' as http;

/// 服务端 API 基址。打包/运行时用 --dart-define=API_BASE_URL=https://example.com/v1 覆盖。
const kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/v1',
);

/// 在线账号公开信息。
class OnlineAccount {
  const OnlineAccount({
    required this.accountId,
    this.email,
    this.phone,
    required this.displayName,
  });

  final String accountId;
  final String? email;
  final String? phone;
  final String displayName;
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
  CloudAuthApi({http.Client? client, String baseUrl = kApiBaseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  final http.Client _client;
  final String _baseUrl;

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

  /// 登出（幂等，失败可忽略）。
  Future<void> logout(String refreshToken) async {
    try {
      await _post('/auth/logout', {'refreshToken': refreshToken});
    } on CloudAuthException {
      // 幂等设计：网络失败时仅清除本地 token
    }
  }

  OnlineAccount _parseAccount(Map<String, dynamic> json) => OnlineAccount(
        accountId: json['accountId'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        displayName: json['displayName'] as String,
      );

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {
      throw const CloudAuthException('网络连接失败，请稍后重试');
    }
    if (response.statusCode == 204) return const {};
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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
