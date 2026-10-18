import 'dart:convert';
import 'dart:io';

import 'package:english_village/app/api_base_url_controller.dart';
import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/data/sources/api_base_url.dart';
import 'package:english_village/data/sources/cloud_auth_api.dart';
import 'package:english_village/data/sources/settings_store.dart';
import 'package:english_village/features/auth/api_base_url_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _IdleAuth extends StateNotifier<AuthState> implements AuthController {
  _IdleAuth() : super(const AuthState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness() {
  return ProviderScope(
    overrides: [authProvider.overrideWith((ref) => _IdleAuth())],
    child: const MaterialApp(home: Scaffold(body: ApiBaseUrlButton())),
  );
}

void main() {
  test('整理服务地址', () {
    expect(normalizeApiBaseUrl('  '), '');
    expect(
      normalizeApiBaseUrl('http://192.168.1.8:8787'),
      'http://192.168.1.8:8787/v1',
    );
    expect(
      normalizeApiBaseUrl('http://192.168.1.8:8787/v1/'),
      'http://192.168.1.8:8787/v1',
    );
    expect(
      normalizeApiBaseUrl('192.168.1.8:8787'),
      'http://192.168.1.8:8787/v1',
    );
    expect(
      normalizeApiBaseUrl('https://example.com/custom'),
      'https://example.com/custom',
    );
    expect(normalizeApiBaseUrl('ftp://example.com'), isNull);
    expect(normalizeApiBaseUrl('http://'), isNull);
  });

  test('请求跟着当前服务地址走', () async {
    final seen = <String>[];
    var base = 'http://first:8787/v1';
    final client = MockClient((request) async {
      seen.add(request.url.toString());
      return http.Response(
        jsonEncode({
          'account': {'accountId': 'acc-1', 'displayName': 'a'},
          'accessToken': 'at',
          'refreshToken': 'rt',
        }),
        200,
      );
    });
    final api = CloudAuthApi(client: client, readBaseUrl: () => base);
    await api.login(email: 'a@example.com', password: 'secret6');
    base = 'http://second:8787/v1';
    await api.login(email: 'a@example.com', password: 'secret6');
    expect(seen, [
      'http://first:8787/v1/auth/login',
      'http://second:8787/v1/auth/login',
    ]);
  });

  group('应用内保存', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('api_base_url');
      Hive.init(temp.path);
      await Hive.openBox<String>(SettingsStore.boxName);
    });

    tearDown(() async {
      await Hive.close();
      await temp.delete(recursive: true);
    });

    test('空配置用默认地址，保存后下次仍在', () async {
      final settings = SettingsStore();
      expect(settings.apiBaseUrl, kApiBaseUrl);
      await settings.setApiBaseUrl('http://10.0.0.8:8787/v1');
      expect(SettingsStore().apiBaseUrl, 'http://10.0.0.8:8787/v1');
      await settings.setApiBaseUrl(null);
      expect(settings.apiBaseUrl, kApiBaseUrl);
    });

    test('保存后控制器和存储一起更新，空值恢复默认', () async {
      final controller = ApiBaseUrlController(SettingsStore());
      addTearDown(controller.dispose);
      await controller.apply('http://10.0.0.8:8787/v1');
      expect(controller.state, 'http://10.0.0.8:8787/v1');
      expect(controller.isCustom, isTrue);
      await controller.apply(null);
      expect(controller.state, kApiBaseUrl);
      expect(controller.isCustom, isFalse);
    });

    testWidgets('对话框打开时带上当前地址', (tester) async {
      await tester.pumpWidget(_harness());
      expect(find.text('服务地址 $kApiBaseUrl'), findsOneWidget);
      await tester.tap(find.byType(ApiBaseUrlButton));
      await tester.pump();
      expect(find.text('服务地址'), findsWidgets);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        kApiBaseUrl,
      );
    });

    testWidgets('非法地址留在对话框里', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.tap(find.byType(ApiBaseUrlButton));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'ftp://example.com');
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await tester.pump();
      expect(find.text('请输入 http 或 https 地址'), findsOneWidget);
      expect(find.text('服务地址'), findsOneWidget);
    });
  });
}
