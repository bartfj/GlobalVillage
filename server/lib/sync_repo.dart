import 'dart:convert';

import 'package:postgres/postgres.dart';

/// 账号的最新同步快照（每账号仅一份，见 docs/在线账号功能设计.md §5）。
class SyncRecord {
  SyncRecord({
    required this.payload,
    required this.clientUpdatedAt,
    required this.serverUpdatedAt,
  });

  /// SyncSnapshot JSON（progress/rewards/track，schemaVersion=1）
  final Map<String, dynamic> payload;

  /// 客户端提交快照时的时钟（毫秒），track 合并参考
  final int clientUpdatedAt;

  final DateTime serverUpdatedAt;

  Map<String, Object?> toJson() => {
        'payload': payload,
        'clientUpdatedAt': clientUpdatedAt,
        'serverUpdatedAt': serverUpdatedAt.millisecondsSinceEpoch,
      };
}

abstract class SyncRepo {
  /// 读取最新快照；从未同步返回 null。
  Future<SyncRecord?> get(String accountId);

  /// 整包替换快照；[baseClientUpdatedAt] 提供且与现值不一致时抛 [SyncConflictException]。
  Future<SyncRecord> put(
    String accountId,
    Map<String, dynamic> payload,
    int clientUpdatedAt, {
    int? baseClientUpdatedAt,
  });
}

/// 乐观并发冲突：客户端基于旧快照合并上传。
class SyncConflictException implements Exception {
  SyncConflictException(this.currentClientUpdatedAt);

  final int? currentClientUpdatedAt;

  @override
  String toString() => 'SyncConflictException($currentClientUpdatedAt)';
}

/// 内存实现，供本地开发与单元测试。
class InMemorySyncRepo implements SyncRepo {
  final _records = <String, SyncRecord>{};

  @override
  Future<SyncRecord?> get(String accountId) async => _records[accountId];

  @override
  Future<SyncRecord> put(
    String accountId,
    Map<String, dynamic> payload,
    int clientUpdatedAt, {
    int? baseClientUpdatedAt,
  }) async {
    final current = _records[accountId];
    if (baseClientUpdatedAt != null &&
        current != null &&
        current.clientUpdatedAt != baseClientUpdatedAt) {
      throw SyncConflictException(current.clientUpdatedAt);
    }
    final record = SyncRecord(
      payload: payload,
      clientUpdatedAt: clientUpdatedAt,
      serverUpdatedAt: DateTime.now().toUtc(),
    );
    _records[accountId] = record;
    return record;
  }
}

/// Postgres 实现（表 sync_snapshots，每账号一行）。
class PostgresSyncRepo implements SyncRepo {
  PostgresSyncRepo._(this._conn);

  final Connection _conn;

  static Future<PostgresSyncRepo> connect(String databaseUrl) async {
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
    final repo = PostgresSyncRepo._(conn);
    await repo._migrate();
    return repo;
  }

  Future<void> _migrate() async {
    await _conn.execute('''
CREATE TABLE IF NOT EXISTS sync_snapshots (
  account_id uuid PRIMARY KEY,
  payload jsonb NOT NULL,
  client_updated_at bigint NOT NULL,
  server_updated_at timestamptz NOT NULL DEFAULT now()
)
''');
  }

  @override
  Future<SyncRecord?> get(String accountId) async {
    final result = await _conn.execute(
      Sql.named(
        'SELECT payload, client_updated_at, server_updated_at '
        'FROM sync_snapshots WHERE account_id = @id::uuid LIMIT 1',
      ),
      parameters: {'id': accountId},
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    return SyncRecord(
      payload: Map<String, dynamic>.from(row['payload'] as Map),
      clientUpdatedAt: row['client_updated_at'] as int,
      serverUpdatedAt: row['server_updated_at'] as DateTime,
    );
  }

  @override
  Future<SyncRecord> put(
    String accountId,
    Map<String, dynamic> payload,
    int clientUpdatedAt, {
    int? baseClientUpdatedAt,
  }) async {
    if (baseClientUpdatedAt != null) {
      final current = await get(accountId);
      if (current != null &&
          current.clientUpdatedAt != baseClientUpdatedAt) {
        throw SyncConflictException(current.clientUpdatedAt);
      }
    }
    final result = await _conn.execute(
      Sql.named('''
INSERT INTO sync_snapshots (account_id, payload, client_updated_at)
VALUES (@id::uuid, @payload::jsonb, @clientUpdatedAt)
ON CONFLICT (account_id) DO UPDATE
SET payload = EXCLUDED.payload,
    client_updated_at = EXCLUDED.client_updated_at,
    server_updated_at = now()
RETURNING server_updated_at
'''),
      parameters: {
        'id': accountId,
        'payload': jsonEncode(payload),
        'clientUpdatedAt': clientUpdatedAt,
      },
    );
    return SyncRecord(
      payload: payload,
      clientUpdatedAt: clientUpdatedAt,
      serverUpdatedAt: result.first.toColumnMap()['server_updated_at'] as DateTime,
    );
  }
}
