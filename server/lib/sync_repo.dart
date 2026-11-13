import 'dart:convert';

import 'package:postgres/postgres.dart';

/// 每个账号保留的同步记录条数。
const maxSyncHistory = 10;

const syncSourceClient = 'client';
const syncSourceAdmin = 'admin';

/// 一次同步留在后台的摘要。最新的排在前面。
Map<String, dynamic> buildSyncHistoryEntry({
  required DateTime serverUpdatedAt,
  required int clientUpdatedAt,
  required int lessonCount,
  required String source,
  Map<String, dynamic>? device,
}) => {
  'serverUpdatedAt': serverUpdatedAt.toUtc().toIso8601String(),
  'clientUpdatedAt': clientUpdatedAt,
  'lessonCount': lessonCount,
  'source': source == syncSourceAdmin ? syncSourceAdmin : syncSourceClient,
  if (device != null) 'device': device,
};

List<Map<String, dynamic>> prependSyncHistory(
  List<Map<String, dynamic>> previous,
  Map<String, dynamic> entry,
) => [entry, ...previous].take(maxSyncHistory).toList();

/// 账号的最新同步快照（每账号仅一份，见 docs/在线账号功能设计.md §5）。
class SyncRecord {
  SyncRecord({
    required this.payload,
    required this.clientUpdatedAt,
    required this.serverUpdatedAt,
    this.device,
    this.history = const [],
  });

  /// SyncSnapshot JSON（progress/rewards/track，schemaVersion=1）
  final Map<String, dynamic> payload;

  /// 客户端提交快照时的时钟（毫秒），track 合并参考
  final int clientUpdatedAt;

  final DateTime serverUpdatedAt;

  /// 最后一次上传设备信息（platform/osVersion/appVersion/installId），仅供后台展示。
  final Map<String, dynamic>? device;

  /// 最近若干次同步，不含整包进度。不放进客户端拉取的快照。
  final List<Map<String, dynamic>> history;

  Map<String, Object?> toJson() => {
    'payload': payload,
    'clientUpdatedAt': clientUpdatedAt,
    'serverUpdatedAt': serverUpdatedAt.millisecondsSinceEpoch,
  };
}

/// 列表用的同步摘要，不含整包 payload。
class SyncSummary {
  SyncSummary({
    required this.clientUpdatedAt,
    required this.serverUpdatedAt,
    required this.lessonCount,
    this.device,
  });

  final int clientUpdatedAt;
  final DateTime serverUpdatedAt;
  final int lessonCount;
  final Map<String, dynamic>? device;
}

abstract class SyncRepo {
  /// 读取最新快照；从未同步返回 null。
  Future<SyncRecord?> get(String accountId);

  /// 整包替换快照；[baseClientUpdatedAt] 提供且与现值不一致时抛 [SyncConflictException]。
  /// [device] 为空时保留上一次记录，避免旧客户端或后台同步清空设备信息。
  /// [source] 为 [syncSourceClient] 或 [syncSourceAdmin]，写入最近 10 次记录。
  Future<SyncRecord> put(
    String accountId,
    Map<String, dynamic> payload,
    int clientUpdatedAt, {
    int? baseClientUpdatedAt,
    Map<String, dynamic>? device,
    String source = syncSourceClient,
  });

  /// 删除该账号的快照。没有记录时也成功。
  Future<void> delete(String accountId);

  /// accountId → 摘要。
  Future<Map<String, SyncSummary>> summaries();
}

int lessonCountOf(Map<String, dynamic> payload) {
  final progress = payload['progress'];
  if (progress is Map) return progress.length;
  return 0;
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
    Map<String, dynamic>? device,
    String source = syncSourceClient,
  }) async {
    final current = _records[accountId];
    if (baseClientUpdatedAt != null &&
        current != null &&
        current.clientUpdatedAt != baseClientUpdatedAt) {
      throw SyncConflictException(current.clientUpdatedAt);
    }
    final now = DateTime.now().toUtc();
    final record = SyncRecord(
      payload: payload,
      clientUpdatedAt: clientUpdatedAt,
      serverUpdatedAt: now,
      device: device ?? current?.device,
      history: prependSyncHistory(
        current?.history ?? const [],
        buildSyncHistoryEntry(
          serverUpdatedAt: now,
          clientUpdatedAt: clientUpdatedAt,
          lessonCount: lessonCountOf(payload),
          source: source,
          device: device,
        ),
      ),
    );
    _records[accountId] = record;
    return record;
  }

  @override
  Future<void> delete(String accountId) async {
    _records.remove(accountId);
  }

  @override
  Future<Map<String, SyncSummary>> summaries() async => {
    for (final entry in _records.entries)
      entry.key: SyncSummary(
        clientUpdatedAt: entry.value.clientUpdatedAt,
        serverUpdatedAt: entry.value.serverUpdatedAt,
        lessonCount: lessonCountOf(entry.value.payload),
        device: entry.value.device,
      ),
  };
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
    await _conn.execute('''
ALTER TABLE sync_snapshots ADD COLUMN IF NOT EXISTS device jsonb
''');
    await _conn.execute('''
ALTER TABLE sync_snapshots
ADD COLUMN IF NOT EXISTS history jsonb NOT NULL DEFAULT '[]'::jsonb
''');
  }

  @override
  Future<SyncRecord?> get(String accountId) async {
    final result = await _conn.execute(
      Sql.named(
        'SELECT payload, client_updated_at, server_updated_at, device, history '
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
      device: _deviceOf(row['device']),
      history: _historyOf(row['history']),
    );
  }

  @override
  Future<SyncRecord> put(
    String accountId,
    Map<String, dynamic> payload,
    int clientUpdatedAt, {
    int? baseClientUpdatedAt,
    Map<String, dynamic>? device,
    String source = syncSourceClient,
  }) async {
    final now = DateTime.now().toUtc();
    final entry = buildSyncHistoryEntry(
      serverUpdatedAt: now,
      clientUpdatedAt: clientUpdatedAt,
      lessonCount: lessonCountOf(payload),
      source: source,
      device: device,
    );
    // 版本比较必须与写入处于同一 SQL 操作，避免并发请求同时通过预读检查。
    // 同步记录在同一条语句里前插，并只保留最近 10 次。
    final result = await _conn.execute(
      Sql.named('''
INSERT INTO sync_snapshots (
  account_id, payload, client_updated_at, device, server_updated_at, history
)
VALUES (
  @id::uuid, @payload::jsonb, @clientUpdatedAt, @device::jsonb,
  @serverUpdatedAt, jsonb_build_array(@entry::jsonb)
)
ON CONFLICT (account_id) DO UPDATE
SET payload = EXCLUDED.payload,
    client_updated_at = EXCLUDED.client_updated_at,
    device = COALESCE(EXCLUDED.device, sync_snapshots.device),
    server_updated_at = @serverUpdatedAt,
    history = (
      SELECT COALESCE(jsonb_agg(elem ORDER BY ord), '[]'::jsonb)
      FROM (
        SELECT 0::bigint AS ord, @entry::jsonb AS elem
        UNION ALL
        SELECT ord, elem FROM (
          SELECT (row_number() OVER ())::bigint AS ord, value AS elem
          FROM jsonb_array_elements(
            COALESCE(sync_snapshots.history, '[]'::jsonb)
          )
        ) older
        WHERE ord <= 9
      ) ranked
    )
WHERE @baseClientUpdatedAt::bigint IS NULL
   OR sync_snapshots.client_updated_at = @baseClientUpdatedAt::bigint
RETURNING server_updated_at, device, history
'''),
      parameters: {
        'id': accountId,
        'payload': jsonEncode(payload),
        'clientUpdatedAt': clientUpdatedAt,
        'baseClientUpdatedAt': baseClientUpdatedAt,
        'device': device == null ? null : jsonEncode(device),
        'serverUpdatedAt': now,
        'entry': jsonEncode(entry),
      },
    );
    if (result.isEmpty) {
      throw SyncConflictException((await get(accountId))?.clientUpdatedAt);
    }
    final row = result.first.toColumnMap();
    return SyncRecord(
      payload: payload,
      clientUpdatedAt: clientUpdatedAt,
      serverUpdatedAt: row['server_updated_at'] as DateTime,
      device: _deviceOf(row['device']),
      history: _historyOf(row['history']),
    );
  }

  @override
  Future<void> delete(String accountId) async {
    try {
      await _conn.execute(
        Sql.named('DELETE FROM sync_snapshots WHERE account_id = @id::uuid'),
        parameters: {'id': accountId},
      );
    } on ServerException {
      return;
    }
  }

  @override
  Future<Map<String, SyncSummary>> summaries() async {
    final result = await _conn.execute(
      Sql.named(
        'SELECT account_id::text AS account_id, payload, client_updated_at, '
        'server_updated_at, device FROM sync_snapshots',
      ),
    );
    final map = <String, SyncSummary>{};
    for (final row in result) {
      final columns = row.toColumnMap();
      final payload = Map<String, dynamic>.from(columns['payload'] as Map);
      map[columns['account_id'] as String] = SyncSummary(
        clientUpdatedAt: columns['client_updated_at'] as int,
        serverUpdatedAt: columns['server_updated_at'] as DateTime,
        lessonCount: lessonCountOf(payload),
        device: _deviceOf(columns['device']),
      );
    }
    return map;
  }
}

Map<String, dynamic>? _deviceOf(Object? value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _historyOf(Object? value) {
  final raw = value is String ? jsonDecode(value) : value;
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}
