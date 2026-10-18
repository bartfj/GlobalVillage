import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets/app_version_label.dart';
import 'api_base_url_dialog.dart';
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

  Future<void> _resetPassword() async {
    final nicknames = ref.read(authProvider.notifier).localNicknames();
    if (nicknames.isEmpty || !mounted) return;
    final initial = _nickname.text.trim().isNotEmpty
        ? _nickname.text.trim()
        : nicknames.first;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ResetLocalPasswordDialog(
        nicknames: nicknames,
        initialNickname: nicknames.contains(initial)
            ? initial
            : nicknames.first,
      ),
    );
    if (saved == true && mounted) {
      setState(() => _error = null);
    }
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
              else ...[
                AuthTextField(label: '昵称', controller: _nickname),
                const SizedBox(height: 8),
                _LocalAccountHint(
                  nicknames: ref.read(authProvider.notifier).localNicknames(),
                  onPick: (name) => _nickname.text = name,
                  onReset: _resetPassword,
                ),
              ],
              const SizedBox(height: 16),
              AuthTextField(
                label: '密码',
                controller: _password,
                obscure: true,
                errorText: _error,
              ),
              if (_tab == _AuthTab.online) const ApiBaseUrlButton(),
              const SizedBox(height: 12),
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
              const SizedBox(height: 28),
              const Center(child: AppVersionLabel()),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalAccountHint extends StatelessWidget {
  const _LocalAccountHint({
    required this.nicknames,
    required this.onPick,
    required this.onReset,
  });

  final List<String> nicknames;
  final ValueChanged<String> onPick;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (nicknames.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '本机已有账号',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in nicknames)
              ActionChip(label: Text(name), onPressed: () => onPick(name)),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onReset, child: const Text('忘记密码')),
        ),
      ],
    );
  }
}

class _ResetLocalPasswordDialog extends ConsumerStatefulWidget {
  const _ResetLocalPasswordDialog({
    required this.nicknames,
    required this.initialNickname,
  });

  final List<String> nicknames;
  final String initialNickname;

  @override
  ConsumerState<_ResetLocalPasswordDialog> createState() =>
      _ResetLocalPasswordDialogState();
}

class _ResetLocalPasswordDialogState
    extends ConsumerState<_ResetLocalPasswordDialog> {
  late String _nickname = widget.initialNickname;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
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
    final error = await ref
        .read(authProvider.notifier)
        .resetLocalPassword(
          nickname: _nickname,
          password: _password.text,
          confirm: _confirm.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('重设本地密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _nickname,
            decoration: const InputDecoration(labelText: '昵称'),
            items: [
              for (final name in widget.nicknames)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) setState(() => _nickname = value);
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: '新密码（至少 6 位）'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: InputDecoration(
              labelText: '再次输入新密码',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? '保存中…' : '保存'),
        ),
      ],
    );
  }
}
