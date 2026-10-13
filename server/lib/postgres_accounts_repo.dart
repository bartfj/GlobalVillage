import 'package:postgres/postgres.dart';

import 'accounts_repo.dart';

/// Postgres 实现。表结构见 docs/在线账号功能设计.md §4.1，
/// email/phone 使用部分唯一索引（允许多个 NULL）。
class PostgresAccountsRepo implements AccountsRepo {
  PostgresAccountsRepo._(this._conn);

  final Connection _conn;

  /// 连接 DATABASE_URL（postgres://user:pass@host:port/db?sslmode=require）
  /// 并完成自动建表。
  static Future<PostgresAccountsRepo> connect(String databaseUrl) async {
    final uri = Uri.parse(databaseUrl);
    final userInfo = uri.userInfo.split(':');
    final sslRequired = uri.queryParameters['sslmode'] == 'require';
    final conn = await Connection.open(
      Endpoint(
        host: uri.host.isEmpty ? 'localhost' : uri.host,
        port: uri.port == 0 ? 5432 : uri.port,
        database:
            uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'postgres',
        username: userInfo.first.isEmpty ? null : userInfo.first,
        password: userInfo.length > 1 ? userInfo.sublist(1).join(':') : null,
      ),
      settings: ConnectionSettings(
        sslMode: sslRequired ? SslMode.require : SslMode.disable,
      ),
    );
    final repo = PostgresAccountsRepo._(conn);
    await repo._migrate();
    return repo;
  }

  Future<void> _migrate() async {
    await _conn.execute('''
CREATE TABLE IF NOT EXISTS accounts (
  account_id uuid PRIMARY KEY,
  email text,
  phone text,
  password_hash text NOT NULL,
  display_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
)
''');
    await _conn.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS accounts_email_unique '
      'ON accounts (email) WHERE email IS NOT NULL',
    );
    await _conn.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS accounts_phone_unique '
      'ON accounts (phone) WHERE phone IS NOT NULL',
    );
  }

  @override
  Future<Account> create(Account account) async {
    try {
      final result = await _conn.execute(
        Sql.named('''
INSERT INTO accounts (account_id, email, phone, password_hash, display_name)
VALUES (@id::uuid, @email, @phone, @passwordHash, @displayName)
RETURNING account_id::text AS account_id, email, phone, password_hash,
          display_name, created_at, updated_at
'''),
        parameters: {
          'id': account.accountId,
          'email': account.email,
          'phone': account.phone,
          'passwordHash': account.passwordHash,
          'displayName': account.displayName,
        },
      );
      return _rowToAccount(result.first.toColumnMap());
    } on ServerException catch (e) {
      if (e.code == '23505') {
        final detail = '${e.constraintName ?? ''} ${e.message}';
        throw AccountConflictException(
            detail.contains('email') ? 'email' : 'phone');
      }
      rethrow;
    }
  }

  @override
  Future<Account?> findByEmail(String email) => _findOne(
        'WHERE lower(email) = lower(@email) LIMIT 1',
        {'email': email},
      );

  @override
  Future<Account?> findByPhone(String phone) => _findOne(
        'WHERE phone = @phone LIMIT 1',
        {'phone': phone},
      );

  @override
  Future<Account?> findById(String accountId) => _findOne(
        'WHERE account_id = @id::uuid LIMIT 1',
        {'id': accountId},
      );

  Future<Account?> _findOne(
      String whereClause, Map<String, Object?> parameters) async {
    final result = await _conn.execute(
      Sql.named(
        'SELECT account_id::text AS account_id, email, phone, password_hash, '
        'display_name, created_at, updated_at FROM accounts $whereClause',
      ),
      parameters: parameters,
    );
    if (result.isEmpty) return null;
    return _rowToAccount(result.first.toColumnMap());
  }

  Account _rowToAccount(Map<String, dynamic> row) => Account(
        accountId: row['account_id'] as String,
        email: row['email'] as String?,
        phone: row['phone'] as String?,
        passwordHash: row['password_hash'] as String,
        displayName: row['display_name'] as String,
        createdAt: row['created_at'] as DateTime,
        updatedAt: row['updated_at'] as DateTime,
      );
}
