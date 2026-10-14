import 'dart:io';

import 'package:global_village_server/accounts_repo.dart';
import 'package:global_village_server/api.dart';
import 'package:global_village_server/auth_service.dart';
import 'package:global_village_server/inmemory_accounts_repo.dart';
import 'package:global_village_server/postgres_accounts_repo.dart';
import 'package:global_village_server/sync_repo.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  // 默认 8787，避免与本机 APK 局域网分享占用的 8080 冲突
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8787;
  final secret = Platform.environment['JWT_SECRET'] ?? '';
  if (secret.isEmpty) {
    stderr.writeln('WARNING: JWT_SECRET 未设置，使用开发默认值，禁止用于生产');
  }
  final auth = AuthService(secret.isEmpty ? 'dev-insecure-secret' : secret);

  final AccountsRepo repo;
  final SyncRepo syncRepo;
  final databaseUrl = Platform.environment['DATABASE_URL'] ?? '';
  if (Platform.environment['STORAGE'] == 'memory' || databaseUrl.isEmpty) {
    if (databaseUrl.isEmpty && Platform.environment['STORAGE'] != 'memory') {
      stderr.writeln('WARNING: DATABASE_URL 未设置，回退到内存仓储（重启丢数据）');
    }
    repo = InMemoryAccountsRepo();
    syncRepo = InMemorySyncRepo();
  } else {
    repo = await PostgresAccountsRepo.connect(databaseUrl);
    syncRepo = await PostgresSyncRepo.connect(databaseUrl);
  }

  final server = await shelf_io.serve(
    buildRouter(repo, auth, syncRepo: syncRepo),
    InternetAddress.anyIPv4,
    port,
  );
  print('在线账号服务已启动: http://${server.address.host}:${server.port}/v1');
}
