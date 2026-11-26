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

/// 诊断报告上传。access token 只放在请求头中。
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

  String? get screenshotBaseUrl => normalizeApiBaseUrl(_baseUrl);

  Future<void> submit(
    Map<String, dynamic> report, {
    String? accessToken,
    String? screenshotBaseUrl,
  }) async {
    final includesScreenshot = report.containsKey('screenshot');
    if (includesScreenshot && screenshotBaseUrl == null) {
      throw const ReportSubmitException('截图反馈缺少服务器地址');
    }
    final baseUrl = includesScreenshot ? screenshotBaseUrl! : _baseUrl;
    final path = includesScreenshot ? 'reports/with-screenshot' : 'reports';
    final headers = <String, String>{'content-type': 'application/json'};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['authorization'] = 'Bearer $accessToken';
    }
    final http.Response response;
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/$path'))
        ..followRedirects = !includesScreenshot
        ..headers.addAll(headers)
        ..body = jsonEncode(report);
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 10));
    } on ReportSubmitException {
      rethrow;
    } catch (_) {
      throw const ReportSubmitException('网络连接失败，请稍后重试');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReportSubmitException('上报失败 (${response.statusCode})');
    }

    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw const ReportSubmitException('服务端未确认反馈已接收');
    }
    if (body is! Map<String, dynamic> || body['ok'] != true) {
      throw const ReportSubmitException('服务端未确认反馈已接收');
    }
    if (includesScreenshot &&
        (report['reportId'] is! String ||
            body['reportId'] != report['reportId'] ||
            body['screenshotAccepted'] != true)) {
      throw const ReportSubmitException('服务端未确认截图已接收');
    }
  }
}
