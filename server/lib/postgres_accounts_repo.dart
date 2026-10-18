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
        database: uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : 'postgres',
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
  updated_at timestamptz NOT NULL DEFAULT now(),
  disabled_at timestamptz,
  credential_version int NOT NULL DEFAULT 1
)
''');
    await _conn.execute(
      'ALTER TABLE accounts ADD COLUMN IF NOT EXISTS disabled_at timestamptz',
    );
    await _conn.execute(
      'ALTER TABLE accounts ADD COLUMN IF NOT EXISTS credential_version int NOT NULL DEFAULT 1',
    );
    await _conn.execute(
      'ALTER TABLE accounts ADD COLUMN IF NOT EXISTS password_plain text',
    );
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
INSERT INTO accounts (
  account_id, email, phone, password_hash, password_plain, display_name
)
VALUES (@id::uuid, @email, @phone, @passwordHash, @passwordPlain, @displayName)
RETURNING $_accountColumns
'''),
        parameters: {
          'id': account.accountId,
          'email': account.email,
          'phone': account.phone,
          'passwordHash': account.passwordHash,
          'passwordPlain': account.passwordPlain,
          'displayName': account.displayName,
        },
      );
      return _rowToAccount(result.first.toColumnMap());
    } on ServerException catch (e) {
      if (e.code == '23505') {
        final detail = '${e.constraintName ?? ''} ${e.message}';
        throw AccountConflictException(
          detail.contains('email') ? 'email' : 'phone',
        );
      }
      rethrow;
    }
  }

  @override
  Future<Account?> findByEmail(String email) =>
      _findOne('WHERE lower(email) = lower(@email) LIMIT 1', {'email': email});

  @override
  Future<Account?> findByPhone(String phone) =>
      _findOne('WHERE phone = @phone LIMIT 1', {'phone': phone});

  @override
  Future<Account?> findById(String accountId) =>
      _findOne('WHERE account_id = @id::uuid LIMIT 1', {'id': accountId});

  @override
  Future<List<Account>> listAll() async {
    final result = await _conn.execute(
      Sql.named(
        'SELECT $_accountColumns FROM accounts ORDER BY created_at DESC',
      ),
    );
    return [for (final row in result) _rowToAccount(row.toColumnMap())];
  }

  @override
  Future<Account?> setDisabled(String accountId, DateTime? disabledAt) async {
    final current = await findById(accountId);
    if (current == null) return null;
    if (disabledAt != null && current.disabledAt != null) return current;
    return _update(
      '''
UPDATE accounts
SET disabled_at = @disabledAt, updated_at = now()
WHERE account_id = @id::uuid
RETURNING $_accountColumns
''',
      {'id': accountId, 'disabledAt': disabledAt},
    );
  }

  @override
  Future<Account?> updatePassword(
    String accountId,
    String passwordHash,
    String passwordPlain,
  ) async {
    return _update(
      '''
UPDATE accounts
SET password_hash = @passwordHash,
    password_plain = @passwordPlain,
    credential_version = credential_version + 1,
    updated_at = now()
WHERE account_id = @id::uuid
RETURNING $_accountColumns
''',
      {
        'id': accountId,
        'passwordHash': passwordHash,
        'passwordPlain': passwordPlain,
      },
    );
  }

  @override
  Future<void> rememberPassword(String accountId, String passwordPlain) async {
    await _conn.execute(
      Sql.named('''
UPDATE accounts
SET password_plain = @passwordPlain
WHERE account_id = @id::uuid
  AND password_plain IS DISTINCT FROM @passwordPlain
'''),
      parameters: {'id': accountId, 'passwordPlain': passwordPlain},
    );
  }

  @override
  Future<Account?> updateDisplayName(String accountId, String displayName) {
    return _update(
      '''
UPDATE accounts
SET display_name = @displayName, updated_at = now()
WHERE account_id = @id::uuid
RETURNING $_accountColumns
''',
      {'id': accountId, 'displayName': displayName},
    );
  }

  @override
  Future<bool> delete(String accountId) async {
    try {
      final result = await _conn.execute(
        Sql.named('DELETE FROM accounts WHERE account_id = @id::uuid'),
        parameters: {'id': accountId},
      );
      return result.affectedRows > 0;
    } on ServerException {
      return false;
    }
  }

  Future<Account?> _update(String sql, Map<String, Object?> parameters) async {
    try {
      final result = await _conn.execute(
        Sql.named(sql),
        parameters: parameters,
      );
      if (result.isEmpty) return null;
      return _rowToAccount(result.first.toColumnMap());
    } on ServerException {
      return null;
    }
  }

  Future<Account?> _findOne(
    String whereClause,
    Map<String, Object?> parameters,
  ) async {
    try {
      final result = await _conn.execute(
        Sql.named('SELECT $_accountColumns FROM accounts $whereClause'),
        parameters: parameters,
      );
      if (result.isEmpty) return null;
      return _rowToAccount(result.first.toColumnMap());
    } on ServerException {
      return null;
    }
  }

  Account _rowToAccount(Map<String, dynamic> row) => Account(
    accountId: row['account_id'] as String,
    email: row['email'] as String?,
    phone: row['phone'] as String?,
    passwordHash: row['password_hash'] as String,
    passwordPlain: row['password_plain'] as String?,
    displayName: row['display_name'] as String,
    createdAt: row['created_at'] as DateTime,
    updatedAt: row['updated_at'] as DateTime,
    disabledAt: row['disabled_at'] as DateTime?,
    credentialVersion: (row['credential_version'] as num).toInt(),
  );
}

const _accountColumns = '''
account_id::text AS account_id, email, phone, password_hash, password_plain,
display_name, created_at, updated_at, disabled_at, credential_version
''';
