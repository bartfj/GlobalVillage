import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import 'api_base_url_dialog.dart';
import 'widgets/auth_text_field.dart';

enum _AuthTab { online, local }

/// 注册页：注册成功即登录（在线账号 / 本地账号）
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _identifier = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _AuthTab _tab = _AuthTab.online;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _identifier.addListener(_onChanged);
    _nickname.addListener(_onChanged);
    _password.addListener(_onChanged);
    _confirm.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _identifier.dispose();
    _nickname.dispose();
    _password.dispose();
    _confirm.dispose();
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
      error = await auth.registerOnline(
        email: identifier.contains('@') ? identifier : null,
        phone: identifier.contains('@') ? null : identifier,
        displayName: _nickname.text,
        password: _password.text,
        confirm: _confirm.text,
      );
    } else {
      error = await auth.register(
        nickname: _nickname.text,
        password: _password.text,
        confirm: _confirm.text,
      );
    }
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
    // 注册成功由路由 redirect 自动跳转首页
  }

  @override
  Widget build(BuildContext context) {
    final nicknameOk = _nickname.text.trim().isNotEmpty;
    final identifierOk =
        _tab != _AuthTab.online || _identifier.text.trim().isNotEmpty;
    final valid =
        nicknameOk &&
        identifierOk &&
        _password.text.isNotEmpty &&
        _confirm.text.isNotEmpty;
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
                '创建账号',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _tab == _AuthTab.online
                    ? '进度云端同步，多设备可接力学习'
                    : '仅保存在本设备，可稍后绑定在线账号',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
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
              if (_tab == _AuthTab.online) ...[
                AuthTextField(label: '邮箱或手机号', controller: _identifier),
                const SizedBox(height: 16),
              ],
              AuthTextField(label: '昵称（2-12 个字符）', controller: _nickname),
              const SizedBox(height: 16),
              AuthTextField(
                label: '密码（至少 6 位）',
                controller: _password,
                obscure: true,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: '确认密码',
                controller: _confirm,
                obscure: true,
                errorText: _error,
              ),
              if (_tab == _AuthTab.online) const ApiBaseUrlButton(),
              const SizedBox(height: 12),
              PushableButton(
                label: _busy ? '注册中…' : '注册',
                onPressed: valid && !_busy ? _submit : null,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '已有账号？',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(
                      '去登录',
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
