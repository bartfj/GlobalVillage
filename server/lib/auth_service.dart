import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart' hide SecretKey;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// 验证通过的 token 载荷。
class TokenPayload {
  TokenPayload(this.accountId, this.typ, this.credentialVersion);

  final String accountId;

  /// 'access' 或 'refresh'
  final String typ;

  /// JWT 声明 cv。旧 token 没有该声明时为 null。
  final int? credentialVersion;
}

/// 密码哈希（argon2id）与 JWT 签发/验证。
class AuthService {
  AuthService(this._secret);

  final String _secret;

  static const _accessTtl = Duration(minutes: 15);
  static const _refreshTtl = Duration(days: 30);

  // OWASP 推荐参数：m=19 MiB, t=2, p=1
  static const _argonMemory = 19456;
  static const _argonIterations = 2;
  static const _argonParallelism = 1;
  static const _argonHashLength = 32;

  // ---------------------------------------------------------------------------
  // 密码哈希（argon2id，PHC 风格字符串存储）
  // ---------------------------------------------------------------------------

  Future<String> hashPassword(String password) async {
    final salt = _randomBytes(16);
    final hash = await _derive(password, salt);
    final params = 'm=$_argonMemory,t=$_argonIterations,p=$_argonParallelism';
    return '\$argon2id\$$params\$${base64Encode(salt)}\$${base64Encode(hash)}';
  }

  Future<bool> verifyPassword(String password, String encoded) async {
    try {
      final parts = encoded.split('\$');
      if (parts.length != 5 || parts[1] != 'argon2id') return false;
      final params = {
        for (final kv in parts[2].split(','))
          kv.split('=').first: kv.split('=').last,
      };
      final memory = int.parse(params['m']!);
      final iterations = int.parse(params['t']!);
      final parallelism = int.parse(params['p']!);
      final salt = base64Decode(parts[3]);
      final expected = base64Decode(parts[4]);
      final actual = await _derive(
        password,
        salt,
        memory: memory,
        iterations: iterations,
        parallelism: parallelism,
        hashLength: expected.length,
      );
      return _constantTimeEquals(actual, expected);
    } catch (_) {
      return false;
    }
  }

  Future<List<int>> _derive(
    String password,
    List<int> salt, {
    int memory = _argonMemory,
    int iterations = _argonIterations,
    int parallelism = _argonParallelism,
    int hashLength = _argonHashLength,
  }) async {
    final algorithm = Argon2id(
      memory: memory,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: hashLength,
    );
    final key = await algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return key.extractBytes();
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// 字符串常量时间比较。长度不同也走完较长的一侧，避免按前缀提前返回。
  static bool constantTimeStringEquals(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    final length = left.length > right.length ? left.length : right.length;
    var diff = left.length ^ right.length;
    for (var i = 0; i < length; i++) {
      final lv = i < left.length ? left[i] : 0;
      final rv = i < right.length ? right[i] : 0;
      diff |= lv ^ rv;
    }
    return diff == 0;
  }

  // ---------------------------------------------------------------------------
  // JWT（HS256，sub=accountId，typ=access/refresh）
  // ---------------------------------------------------------------------------

  String issueAccessToken(String accountId, {int credentialVersion = 1}) =>
      _issue(accountId, 'access', _accessTtl, credentialVersion);

  String issueRefreshToken(String accountId, {int credentialVersion = 1}) =>
      _issue(accountId, 'refresh', _refreshTtl, credentialVersion);

  String _issue(
    String accountId,
    String typ,
    Duration ttl,
    int credentialVersion,
  ) {
    final jwt = JWT({
      'sub': accountId,
      'typ': typ,
      'cv': credentialVersion,
    }, issuer: 'global-village-server');
    return jwt.sign(
      SecretKey(_secret),
      algorithm: JWTAlgorithm.HS256,
      expiresIn: ttl,
    );
  }

  /// 验证 token，无效或过期返回 null。
  TokenPayload? verify(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secret));
      final payload = jwt.payload;
      if (payload is! Map) return null;
      final sub = payload['sub'];
      final typ = payload['typ'];
      if (sub is! String || typ is! String) return null;
      final cv = payload['cv'];
      final version = cv is int ? cv : (cv is num ? cv.toInt() : null);
      return TokenPayload(sub, typ, version);
    } on JWTException {
      return null;
    }
  }
}
