import 'dart:convert';
import 'dart:io';

import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/features/auth/register_page.dart';
import 'package:english_village/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:english_village/data/models/user.dart';
import 'package:english_village/data/repositories/user_repository.dart';
import 'package:english_village/app/api_base_url_controller.dart';
import 'package:english_village/data/sources/cloud_auth_api.dart';
import 'package:english_village/data/sources/settings_store.dart';
import 'package:english_village/data/sources/token_store.dart';
import 'package:english_village/data/sources/user_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeCloudAuth extends CloudAuthApi {
  Object? registerError;
  Object? loginError;
  String nextAccessToken = 'access-token';
  String nextRefreshToken = 'refresh-token';
  String accountId = 'acc-123';
  String displayName = 'ann';
  String? email;
  String? phone;

  @override
  Future<OnlineAuthResult> register({
    String? email,
    String? phone,
    required String password,
    String? displayName,
  }) async {
    if (registerError != null) throw registerError!;
    this.email = email;
    this.phone = phone;
    if (displayName != null) this.displayName = displayName;
    return OnlineAuthResult(
      account: OnlineAccount(
        accountId: accountId,
        email: email,
        phone: phone,
        displayName: displayName ?? this.displayName,
        createdAt: DateTime.utc(2026, 1, 2),
      ),
      accessToken: nextAccessToken,
      refreshToken: nextRefreshToken,
    );
  }

  @override
  Future<OnlineAuthResult> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    return register(email: email, phone: phone, password: password);
  }

  @override
  Future<String> refreshAccessToken(String refreshToken) async =>
      nextAccessToken;

  @override
  Future<OnlineAccount> fetchMe(String accessToken) async => OnlineAccount(
    accountId: accountId,
    email: email,
    phone: phone,
    displayName: displayName,
    createdAt: DateTime.utc(2026, 1, 2),
  );

  @override
  Future<OnlineAccount> updateProfile(
    String accessToken,
    String displayName,
  ) async {
    this.displayName = displayName;
    return fetchMe(accessToken);
  }

  @override
  Future<void> logout(String refreshToken) async {}
}

class _MemorySettings extends SettingsStore {
  @override
  String get apiBaseUrl => kApiBaseUrl;

  @override
  Future<void> setApiBaseUrl(String? url) async {}
}

void main() {
  group('CloudAuthApi', () {
    test('注册成功解析账号与双 token', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'a@example.com');
        return http.Response(
          jsonEncode({
            'account': {
              'accountId': 'acc-1',
              'email': 'a@example.com',
              'phone': null,
              'displayName': 'a',
            },
            'accessToken': 'at',
            'refreshToken': 'rt',
          }),
          200,
        );
      });
      final api = CloudAuthApi(client: client, baseUrl: 'http://x/v1');
      final result = await api.register(
        email: 'a@example.com',
        password: 'secret6',
      );
      expect(result.account.accountId, 'acc-1');
      expect(result.accessToken, 'at');
      expect(result.refreshToken, 'rt');
    });

    test('401 映射为带 code/message 的异常', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'code': 'invalid_credentials', 'message': '账号不存在或密码错误'}),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final api = CloudAuthApi(client: client, baseUrl: 'http://x/v1');
      expect(
        () => api.login(email: 'a@example.com', password: 'wrong'),
        throwsA(
          isA<CloudAuthException>()
              .having((e) => e.code, 'code', 'invalid_credentials')
              .having((e) => e.message, 'message', '账号不存在或密码错误')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('网络异常映射为友好错误', () async {
      final client = MockClient(
        (request) async => throw http.ClientException('boom'),
      );
      final api = CloudAuthApi(client: client, baseUrl: 'http://x/v1');
      expect(
        () => api.login(email: 'a@example.com', password: 'secret6'),
        throwsA(
          isA<CloudAuthException>().having(
            (e) => e.message,
            'message',
            '网络连接失败，请稍后重试',
          ),
        ),
      );
    });
  });

  group('在线会话（AuthController）', () {
    late _FakeCloudAuth cloud;
    late MemoryTokenStore tokens;
    late AuthController auth;
    late UserStore store;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('hive_online_test');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UserAdapter());
      }
      await Hive.openBox<User>(UserStore.usersBoxName);
      await Hive.openBox<String>(UserStore.sessionBoxName);
      store = UserStore();
      cloud = _FakeCloudAuth();
      tokens = MemoryTokenStore();
      auth = AuthController(
        UserRepository(store: store),
        cloudAuth: cloud,
        tokenStore: tokens,
      );
    });

    tearDown(() async {
      auth.dispose();
      await Hive.box<User>(UserStore.usersBoxName).deleteFromDisk();
      await Hive.box<String>(UserStore.sessionBoxName).deleteFromDisk();
      await Hive.close();
    });

    test('在线注册成功建立 online:<accountId> 会话并保存 refresh token', () async {
      final error = await auth.registerOnline(
        email: 'a@example.com',
        displayName: 'ann',
        password: 'secret6',
        confirm: 'secret6',
      );
      expect(error, isNull);
      expect(auth.state.userKey, 'online:acc-123');
      expect(auth.state.isOnline, isTrue);
      expect(auth.state.mode, AuthMode.online);
      expect(auth.state.accessToken, 'access-token');
      expect(auth.state.displayName, 'ann');
      expect(tokens.token, 'refresh-token');
      expect(store.currentSession, 'online:acc-123');
      expect(store.currentDisplayName, 'ann');
    });

    test('本地校验：缺标识 / 短密码 / 两次密码不一致', () async {
      expect(
        await auth.registerOnline(
          displayName: 'ann',
          password: 'secret6',
          confirm: 'secret6',
        ),
        '请输入邮箱或手机号',
      );
      expect(
        await auth.registerOnline(
          email: 'a@example.com',
          displayName: 'ann',
          password: '12345',
          confirm: '12345',
        ),
        '密码至少 6 位',
      );
      expect(
        await auth.registerOnline(
          email: 'a@example.com',
          displayName: 'ann',
          password: 'secret6',
          confirm: 'secret7',
        ),
        '两次输入的密码不一致',
      );
      expect(auth.state.hasSession, isFalse);
    });

    test('服务端错误文案透传', () async {
      cloud.registerError = const CloudAuthException(
        '该邮箱已被注册',
        statusCode: 409,
        code: 'email_taken',
      );
      final error = await auth.registerOnline(
        email: 'a@example.com',
        displayName: 'ann',
        password: 'secret6',
        confirm: 'secret6',
      );
      expect(error, '该邮箱已被注册');
      expect(auth.state.hasSession, isFalse);
    });

    test('在线登出清除会话与 refresh token', () async {
      await auth.registerOnline(
        email: 'a@example.com',
        displayName: 'ann',
        password: 'secret6',
        confirm: 'secret6',
      );
      await auth.logout();
      expect(auth.state.hasSession, isFalse);
      expect(tokens.token, isNull);
      expect(store.currentSession, isNull);
    });

    test('修改昵称后写入会话', () async {
      await auth.registerOnline(
        email: 'a@example.com',
        displayName: 'ann',
        password: 'secret6',
        confirm: 'secret6',
      );
      expect(await auth.updateDisplayName('新昵称'), isNull);
      expect(auth.state.displayName, '新昵称');
      expect(store.currentDisplayName, '新昵称');
    });

    test('重启后用 refresh token 静默换新 access token', () async {
      await auth.registerOnline(
        email: 'a@example.com',
        displayName: 'ann',
        password: 'secret6',
        confirm: 'secret6',
      );
      cloud.nextAccessToken = 'access-token-v2';
      final restored = AuthController(
        UserRepository(store: store),
        cloudAuth: cloud,
        tokenStore: tokens,
      );
      addTearDown(restored.dispose);
      // 构造函数中静默刷新，等待微任务完成
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(restored.state.userKey, 'online:acc-123');
      expect(restored.state.displayName, 'ann');
      expect(restored.state.accessToken, 'access-token-v2');
    });
  });

  testWidgets('在线注册未填昵称不能提交', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiBaseUrlProvider.overrideWith(
            (ref) => ApiBaseUrlController(_MemorySettings()),
          ),
        ],
        child: const MaterialApp(home: RegisterPage()),
      ),
    );
    expect(find.byType(TextField), findsNWidgets(4));
    await tester.enterText(find.byType(TextField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret6');
    await tester.enterText(find.byType(TextField).at(3), 'secret6');
    await tester.pump();
    expect(
      tester.widget<PushableButton>(find.byType(PushableButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).at(1), 'ann');
    await tester.pump();
    expect(
      tester.widget<PushableButton>(find.byType(PushableButton)).onPressed,
      isNotNull,
    );
  });

  group('User Hive 兼容', () {
    test('在线绑定字段读写往返', () async {
      final dir = await Directory.systemTemp.createTemp('hive_user_bind');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UserAdapter());
      }
      final box = await Hive.openBox<User>('bind_test');
      await box.put(
        'alice',
        User(
          nickname: 'alice',
          passwordHash: 'h',
          salt: 's',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
          onlineAccountId: 'acc-9',
          onlineBoundAt: 2000,
        ),
      );
      final loaded = box.get('alice')!;
      expect(loaded.onlineAccountId, 'acc-9');
      expect(loaded.onlineBoundAt, 2000);
      await box.deleteFromDisk();
      await Hive.close();
    });
  });
}
