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

  /// 打包尚未入队的事件并发送全部待发送报告。全部成功返回 true。
  Future<bool> flush() async {
    await _log.enqueueUnsent(
      installId: await _settings.ensureInstallId(),
      accountId: _accountId(),
    );
    return _sendPending();
  }

  /// 用户主动反馈。说明可空，始终附上最近日志。
  Future<bool> submitNote(String note) async {
    await _log.enqueueFeedback(
      note: note,
      installId: await _settings.ensureInstallId(),
      accountId: _accountId(),
    );
    return _sendPending();
  }

  Future<bool> _sendPending() async {
    final token = _readAuth().accessToken;
    for (final report in List<Map<String, dynamic>>.from(_log.pending)) {
      final id = report['reportId'];
      if (id is! String || id.isEmpty) continue;
      try {
        await _api.submit(report, accessToken: token);
        await _log.markSent(id);
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  String? _accountId() {
    final auth = _readAuth();
    final userKey = auth.userKey;
    if (!auth.isOnline || userKey == null) return null;
    final id = userKey.substring(AuthState.onlineKeyPrefix.length);
    return id.isEmpty ? null : id;
  }
}
