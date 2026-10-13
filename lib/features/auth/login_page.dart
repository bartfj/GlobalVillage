import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import 'widgets/auth_text_field.dart';

enum _AuthTab { online, local }

/// 登录页（在线账号 / 本地账号）
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifier = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  _AuthTab _tab = _AuthTab.online;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _identifier.addListener(_onChanged);
    _nickname.addListener(_onChanged);
    _password.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _identifier.dispose();
    _nickname.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    final String? error;
    if (_tab == _AuthTab.online) {
      final identifier = _identifier.text.trim();
      error = await auth.loginOnline(
        email: identifier.contains('@') ? identifier : null,
        phone: identifier.contains('@') ? null : identifier,
        password: _password.text,
      );
    } else {
      error = await auth.login(
        nickname: _nickname.text,
        password: _password.text,
      );
    }
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
    // 登录成功由路由 redirect 自动跳转首页
  }

  @override
  Widget build(BuildContext context) {
    final valid = _tab == _AuthTab.online
        ? _identifier.text.trim().isNotEmpty && _password.text.isNotEmpty
        : _nickname.text.trim().isNotEmpty && _password.text.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '欢迎回来',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '登录后继续你的学习进度',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SegmentedButton<_AuthTab>(
                segments: const [
                  ButtonSegment(
                    value: _AuthTab.online,
                    label: Text('在线账号'),
                    icon: Icon(Icons.cloud_outlined),
                  ),
                  ButtonSegment(
                    value: _AuthTab.local,
                    label: Text('本地账号'),
                    icon: Icon(Icons.person_outline),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (selection) => setState(() {
                  _tab = selection.first;
                  _error = null;
                }),
              ),
              const SizedBox(height: 24),
              if (_tab == _AuthTab.online)
                AuthTextField(label: '邮箱或手机号', controller: _identifier)
              else
                AuthTextField(label: '昵称', controller: _nickname),
              const SizedBox(height: 16),
              AuthTextField(
                label: '密码',
                controller: _password,
                obscure: true,
                errorText: _error,
              ),
              const SizedBox(height: 28),
              PushableButton(
                label: _busy ? '登录中…' : '登录',
                onPressed: valid && !_busy ? _submit : null,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '还没有账号？',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text(
                      '去注册',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
