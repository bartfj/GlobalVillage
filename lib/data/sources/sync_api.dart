import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cloud_auth_api.dart';

/// 云端快照（服务端存整包）。
class RemoteSnapshot {
  const RemoteSnapshot({
    required this.payload,
    required this.clientUpdatedAt,
    this.byteLength = 0,
  });

  final Map<String, dynamic> payload;
  final int clientUpdatedAt;

  /// 本次拉取响应的字节数，供同步过程展示。
  final int byteLength;
}

/// 进度同步 API（GET/PUT /sync，Bearer 鉴权）。
class SyncApi {
  SyncApi({
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

  Map<String, String> _headers(String accessToken) => {
    'authorization': 'Bearer $accessToken',
    'content-type': 'application/json',
  };

  /// 拉取最新快照；从未同步返回 null。401 时抛 [CloudAuthException]（code=invalid_token）。
  Future<RemoteSnapshot?> pull(String accessToken) async {
    final http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$_baseUrl/sync'),
        headers: _headers(accessToken),
      );
    } catch (_) {
      throw const CloudAuthException('网络连接失败，请稍后重试');
    }
    if (response.statusCode == 204) return null;
    if (response.statusCode == 401) {
      throw const CloudAuthException(
        '登录已过期',
        statusCode: 401,
        code: 'invalid_token',
      );
    }
    if (response.statusCode >= 400) {
      throw CloudAuthException('同步失败', statusCode: response.statusCode);
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return RemoteSnapshot(
      payload: (json['payload'] as Map).cast<String, dynamic>(),
      clientUpdatedAt: json['clientUpdatedAt'] as int,
      byteLength: response.bodyBytes.length,
    );
  }

  /// 上传整包快照；409 sync_conflict 时抛 [CloudAuthException]（code=sync_conflict）。
  ///
  /// [device] 仅用于管理后台展示，不参与合并。
  /// 返回实际上传的请求体字节数。
  Future<int> push(
    String accessToken,
    Map<String, dynamic> payload,
    int clientUpdatedAt, {
    int? baseClientUpdatedAt,
    Map<String, dynamic>? device,
    Map<String, dynamic>? trace,
  }) async {
    final body = jsonEncode({
      'payload': payload,
      'clientUpdatedAt': clientUpdatedAt,
      if (baseClientUpdatedAt != null)
        'baseClientUpdatedAt': baseClientUpdatedAt,
      if (device != null) 'device': device,
      if (trace != null) 'trace': trace,
    });
    final http.Response response;
    try {
      response = await _client.put(
        Uri.parse('$_baseUrl/sync'),
        headers: _headers(accessToken),
        body: body,
      );
    } catch (_) {
      throw const CloudAuthException('网络连接失败，请稍后重试');
    }
    if (response.statusCode < 400) return utf8.encode(body).length;
    String? code;
    String message = '同步失败';
    try {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      code = json['code'] as String?;
      message = (json['message'] as String?) ?? message;
    } catch (_) {
      // 保留默认文案
    }
    throw CloudAuthException(
      message,
      statusCode: response.statusCode,
      code: code,
    );
  }

  /// 上传完成后补报耗时。失败不影响同步结果。
  Future<void> reportTrace(
    String accessToken,
    int clientUpdatedAt,
    Map<String, dynamic> trace,
  ) async {
    try {
      await _client.post(
        Uri.parse('$_baseUrl/sync/trace'),
        headers: _headers(accessToken),
        body: jsonEncode({
          'clientUpdatedAt': clientUpdatedAt,
          'trace': trace,
        }),
      );
    } catch (_) {
      // 过程记录丢了也不要让用户看到同步失败。
    }
  }
}
