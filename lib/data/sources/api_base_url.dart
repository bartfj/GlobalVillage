/// 服务端 API 基址。打包/运行时用 --dart-define=API_BASE_URL=https://example.com/v1 覆盖。
const kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8787/v1',
);

/// 整理用户输入的服务地址。
///
/// 空字符串表示恢复默认。没有路径时补上 `/v1`。非法地址返回 null。
String? normalizeApiBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  final text = trimmed.contains('://') ? trimmed : 'http://$trimmed';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;

  var path = uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path.isEmpty || path == '/') path = '/v1';

  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
}
