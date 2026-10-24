import 'dart:math';

/// 在线账号模型（见 docs/在线账号功能设计.md §4.1）。
class Account {
  Account({
    required this.accountId,
    this.email,
    this.phone,
    required this.passwordHash,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.disabledAt,
    this.credentialVersion = 1,
  });

  final String accountId;
  final String? email;
  final String? phone;
  final String passwordHash;

  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 非空表示已停用。
  final DateTime? disabledAt;

  /// 写入 JWT 的 cv。重置密码时加 1。
  final int credentialVersion;

  Map<String, Object?> toPublicJson() => {
    'accountId': accountId,
    'email': email,
    'phone': phone,
    'displayName': displayName,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// 唯一约束冲突（email 或 phone 已存在）。
class AccountConflictException implements Exception {
  AccountConflictException(this.field);

  /// 'email' 或 'phone'
  final String field;

  @override
  String toString() => 'AccountConflictException($field)';
}

abstract class AccountsRepo {
  /// 创建账号；email/phone 唯一冲突时抛 [AccountConflictException]。
  Future<Account> create(Account account);

  Future<Account?> findByEmail(String email);

  Future<Account?> findByPhone(String phone);

  Future<Account?> findById(String accountId);

  /// 按创建时间倒序。
  Future<List<Account>> listAll();

  /// [disabledAt] 为 null 时恢复。已停用再次停用则保持原时间。
  /// 账号不存在返回 null。
  Future<Account?> setDisabled(String accountId, DateTime? disabledAt);

  /// 写入新密码哈希，并将 credentialVersion 加 1。账号不存在返回 null。
  Future<Account?> updatePassword(String accountId, String passwordHash);

  /// 只改昵称和 updatedAt。账号不存在返回 null。
  Future<Account?> updateDisplayName(String accountId, String displayName);

  /// 删除账号行。不存在返回 false。
  Future<bool> delete(String accountId);
}

/// 生成 UUID v4。
String newAccountId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
