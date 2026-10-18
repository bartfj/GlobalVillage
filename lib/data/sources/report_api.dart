import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base_url.dart';

/// 诊断报告上传失败。
class ReportSubmitException implements Exception {
  const ReportSubmitException(this.message);

  final String message;

  @override
  String toString() => 'ReportSubmitException($message)';
}

/// `POST /v1/reports`。不要求登录；有 access token 时附在请求头，不放进正文。
class ReportApi {
  ReportApi({
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

  Future<void> submit(
    Map<String, dynamic> report, {
    String? accessToken,
  }) async {
    final headers = <String, String>{'content-type': 'application/json'};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['authorization'] = 'Bearer $accessToken';
    }
    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$_baseUrl/reports'),
        headers: headers,
        body: jsonEncode(report),
      );
    } on ReportSubmitException {
      rethrow;
    } catch (_) {
      throw const ReportSubmitException('网络连接失败，请稍后重试');
    }
    if (response.statusCode >= 400) {
      throw ReportSubmitException('上报失败 (${response.statusCode})');
    }
  }
}
