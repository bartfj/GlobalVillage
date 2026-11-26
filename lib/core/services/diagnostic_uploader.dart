import 'dart:typed_data';

import '../../app/auth_controller.dart';
import '../../data/sources/report_api.dart';
import '../../data/sources/settings_store.dart';
import 'diagnostic_log.dart';

/// 把本地未发送的诊断报告上传到现有服务端。失败时保留队列。
class DiagnosticUploader {
  DiagnosticUploader({
    required DiagnosticLog log,
    required ReportApi api,
    required SettingsStore settings,
    required AuthState Function() readAuth,
  }) : _log = log,
       _api = api,
       _settings = settings,
       _readAuth = readAuth;

  final DiagnosticLog _log;
  final ReportApi _api;
  final SettingsStore _settings;
  final AuthState Function() _readAuth;
  final _sending = <String, Future<bool>>{};

  /// 打包尚未入队的事件并发送全部待发送报告。全部成功返回 true。
  Future<bool> flush() async {
    final accountId = _accountId(_readAuth());
    await _log.enqueueUnsent(
      installId: await _settings.ensureInstallId(),
      accountId: accountId,
    );
    var allSent = true;
    for (final report in _log.pendingReports) {
      if (!await _sendReport(report)) allSent = false;
    }
    return allSent;
  }

  Future<bool> submitNote(String note) => submitFeedback(note: note);

  /// 先保存用户反馈，再发送本条报告。false 表示已留在本地队列。
  Future<bool> submitFeedback({
    required String note,
    Uint8List? screenshot,
  }) async {
    final accountId = _accountId(_readAuth());
    final screenshotBaseUrl = screenshot == null
        ? null
        : _api.screenshotBaseUrl;
    final report = await _log.enqueueFeedback(
      note: note,
      installId: await _settings.ensureInstallId(),
      accountId: accountId,
      screenshot: screenshot,
      screenshotBaseUrl: screenshotBaseUrl,
    );
    return _sendReport(report);
  }

  Future<bool> _sendReport(PendingDiagnosticReport item) async {
    final id = item.report['reportId'];
    if (id is! String || id.isEmpty) return false;
    final active = _sending[id];
    if (active != null) return active;
    if (!_log.isPending(id)) return true;

    final attempt = _deliver(item, id);
    _sending[id] = attempt;
    try {
      return await attempt;
    } finally {
      _sending.remove(id);
    }
  }

  Future<bool> _deliver(PendingDiagnosticReport item, String id) async {
    final report = item.report;
    final auth = _readAuth();
    var token = auth.accessToken;
    String? screenshotBaseUrl;
    if (report.containsKey('screenshot')) {
      screenshotBaseUrl = item.screenshotBaseUrl;
      if (screenshotBaseUrl == null ||
          screenshotBaseUrl != _api.screenshotBaseUrl) {
        return false;
      }
      final context = report['context'];
      if (context is! Map<String, dynamic>) return false;
      final originalAccount = context['accountId'];
      if (originalAccount == null) {
        token = null;
      } else if (_accountId(auth) != originalAccount ||
          token == null ||
          token.isEmpty) {
        return false;
      }
    }
    try {
      await _api.submit(
        report,
        accessToken: token,
        screenshotBaseUrl: screenshotBaseUrl,
      );
      await _log.markSent(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  String? _accountId(AuthState auth) {
    final userKey = auth.userKey;
    if (!auth.isOnline || userKey == null) return null;
    final id = userKey.substring(AuthState.onlineKeyPrefix.length);
    return id.isEmpty ? null : id;
  }
}
