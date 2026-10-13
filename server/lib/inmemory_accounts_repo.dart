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
}
