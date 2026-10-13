import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// refresh token 持久化（安全存储）。
abstract class TokenStore {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);
  Future<void> clear();
}

/// 基于 flutter_secure_storage 的实现（Windows DPAPI / Android Keystore / iOS Keychain）。
class SecureTokenStore extends TokenStore {
  static const _key = 'online_refresh_token';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _key);

  @override
  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// 内存实现，供单元测试。
class MemoryTokenStore extends TokenStore {
  String? token;

  @override
  Future<String?> readRefreshToken() async => token;

  @override
  Future<void> writeRefreshToken(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
