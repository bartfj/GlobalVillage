import 'accounts_repo.dart';

/// 内存实现，方便本地无 Postgres 开发与单元测试。
class InMemoryAccountsRepo implements AccountsRepo {
  final _byId = <String, Account>{};

  @override
  Future<Account> create(Account account) async {
    if (account.email != null &&
        _byId.values.any((a) => a.email == account.email)) {
      throw AccountConflictException('email');
    }
    if (account.phone != null &&
        _byId.values.any((a) => a.phone == account.phone)) {
      throw AccountConflictException('phone');
    }
    _byId[account.accountId] = account;
    return account;
  }

  @override
  Future<Account?> findByEmail(String email) async {
    for (final account in _byId.values) {
      if (account.email == email) return account;
    }
    return null;
  }

  @override
  Future<Account?> findByPhone(String phone) async {
    for (final account in _byId.values) {
      if (account.phone == phone) return account;
    }
    return null;
  }

  @override
  Future<Account?> findById(String accountId) async => _byId[accountId];

  @override
  Future<List<Account>> listAll() async {
    final accounts = _byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return accounts;
  }

  @override
  Future<Account?> setDisabled(String accountId, DateTime? disabledAt) async {
    final current = _byId[accountId];
    if (current == null) return null;
    if (disabledAt != null && current.disabledAt != null) return current;
    final updated = Account(
      accountId: current.accountId,
      email: current.email,
      phone: current.phone,
      passwordHash: current.passwordHash,
      displayName: current.displayName,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      disabledAt: disabledAt,
      credentialVersion: current.credentialVersion,
    );
    _byId[accountId] = updated;
    return updated;
  }

  @override
  Future<Account?> updatePassword(String accountId, String passwordHash) async {
    final current = _byId[accountId];
    if (current == null) return null;
    final updated = Account(
      accountId: current.accountId,
      email: current.email,
      phone: current.phone,
      passwordHash: passwordHash,
      displayName: current.displayName,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      disabledAt: current.disabledAt,
      credentialVersion: current.credentialVersion + 1,
    );
    _byId[accountId] = updated;
    return updated;
  }

  @override
  Future<Account?> updateDisplayName(
    String accountId,
    String displayName,
  ) async {
    final current = _byId[accountId];
    if (current == null) return null;
    final updated = Account(
      accountId: current.accountId,
      email: current.email,
      phone: current.phone,
      passwordHash: current.passwordHash,
      displayName: displayName,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      disabledAt: current.disabledAt,
      credentialVersion: current.credentialVersion,
    );
    _byId[accountId] = updated;
    return updated;
  }

  @override
  Future<bool> delete(String accountId) async =>
      _byId.remove(accountId) != null;
}
