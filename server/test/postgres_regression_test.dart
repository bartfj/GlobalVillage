import 'dart:io';

import 'package:global_village_server/accounts_repo.dart';
import 'package:global_village_server/auth_service.dart';
import 'package:global_village_server/postgres_accounts_repo.dart';
import 'package:global_village_server/sync_repo.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

void main() {
  final databaseUrl = Platform.environment['TEST_DATABASE_URL'];
  group('PostgreSQL 回归（需独立测试数据库）', () {
    late Connection control;
    setUp(() async {
      final uri = Uri.parse(databaseUrl!);
      final credentials = uri.userInfo.split(':');
      control = await Connection.open(
        Endpoint(
          host: uri.host,
          port: uri.port == 0 ? 5432 : uri.port,
          database: uri.pathSegments.first,
          username: credentials.first,
          password: credentials.length > 1
              ? credentials.sublist(1).join(':')
              : null,
        ),
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      );
    });
    tearDown(() async => control.close());

    test('同一旧版本的并发写入只能成功一次', () async {
      final first = await PostgresSyncRepo.connect(databaseUrl!);
      final second = await PostgresSyncRepo.connect(databaseUrl);
      final id = newAccountId();
      await first.put(id, {
        'progress': {
          'u1l1': {'score': 80},
        },
      }, 100);
      await control.execute('BEGIN');
      try {
        await control.execute(
          Sql.named(
            'SELECT account_id FROM sync_snapshots WHERE account_id = @id::uuid FOR UPDATE',
          ),
          parameters: {'id': id},
        );
        Future<Object> attempt(PostgresSyncRepo repo, int version) async {
          try {
            return await repo.put(
              id,
              {
                'progress': {
                  'u1l1': {'score': version},
                },
              },
              version,
              baseClientUpdatedAt: 100,
            );
          } on SyncConflictException catch (error) {
            return error;
          }
        }

        final a = attempt(first, 200);
        final b = attempt(second, 300);
        // 锁住行，确保两次写入同时等待数据库，而非依赖任务调度碰巧重叠。
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        var waiting = 0;
        while (waiting < 2 && DateTime.now().isBefore(deadline)) {
          final rows = await control.execute(
            "SELECT count(*) FROM pg_stat_activity "
            "WHERE wait_event_type = 'Lock' AND query LIKE '%INSERT INTO sync_snapshots%'",
          );
          waiting = rows.first.first as int;
          if (waiting < 2)
            await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(waiting, 2);
        await control.execute('COMMIT');
        final results = await Future.wait([a, b]);
        expect(results.whereType<SyncRecord>(), hasLength(1));
        expect(results.whereType<SyncConflictException>(), hasLength(1));
        final winner = results.whereType<SyncRecord>().single;
        expect((await first.get(id))!.clientUpdatedAt, winner.clientUpdatedAt);
      } finally {
        await control.execute('ROLLBACK');
        await first.delete(id);
      }
    });

    test('升级移除旧明文密码列并保留登录哈希', () async {
      final repo = await PostgresAccountsRepo.connect(databaseUrl!);
      final auth = AuthService('test-secret');
      final now = DateTime.now().toUtc();
      final account = await repo.create(
        Account(
          accountId: newAccountId(),
          email: '${newAccountId()}@example.com',
          passwordHash: await auth.hashPassword('secret6'),
          displayName: 'Review',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await control.execute(
        'ALTER TABLE accounts ADD COLUMN IF NOT EXISTS password_plain text',
      );
      await control.execute(
        Sql.named(
          'UPDATE accounts SET password_plain = @password WHERE account_id = @id::uuid',
        ),
        parameters: {'password': 'secret6', 'id': account.accountId},
      );
      final upgraded = await PostgresAccountsRepo.connect(databaseUrl);
      final columns = await control.execute(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = 'accounts' AND column_name = 'password_plain'",
      );
      expect(columns, isEmpty);
      final restored = (await upgraded.findById(account.accountId))!;
      expect(
        await auth.verifyPassword('secret6', restored.passwordHash),
        isTrue,
      );
      await upgraded.delete(account.accountId);
    });
  }, skip: databaseUrl == null ? '设置 TEST_DATABASE_URL 指向独立测试数据库' : false);
}
