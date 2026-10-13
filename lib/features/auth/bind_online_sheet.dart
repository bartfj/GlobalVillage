import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import 'widgets/auth_text_field.dart';

/// 本地账号「绑定在线账号」底部面板（docs/在线账号功能设计.md §7.2）。
Future<void> showBindOnlineSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const BindOnlineSheet(),
    ),
  );
}

class BindOnlineSheet extends ConsumerStatefulWidget {
  const BindOnlineSheet({super.key});

  @override
  ConsumerState<BindOnlineSheet> createState() => _BindOnlineSheetState();
}

class _BindOnlineSheetState extends ConsumerState<BindOnlineSheet> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _identifier.addListener(_onChanged);
    _password.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool register}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final identifier = _identifier.text.trim();
    final auth = ref.read(authProvider.notifier);
    final error = register
        ? await auth.registerAndBind(
            email: identifier.contains('@') ? identifier : null,
            phone: identifier.contains('@') ? null : identifier,
            password: _password.text,
          )
        : await auth.loginAndBind(
            email: identifier.contains('@') ? identifier : null,
            phone: identifier.contains('@') ? null : identifier,
            password: _password.text,
          );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final valid =
        _identifier.text.trim().isNotEmpty && _password.text.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '绑定在线账号',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '当前设备的学习进度将与云端合并，多设备可接力学习',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            AuthTextField(label: '邮箱或手机号', controller: _identifier),
            const SizedBox(height: 12),
            AuthTextField(
              label: '密码（至少 6 位）',
              controller: _password,
              obscure: true,
              errorText: _error,
            ),
            const SizedBox(height: 20),
            PushableButton(
              label: _busy ? '处理中…' : '注册并绑定',
              onPressed: valid && !_busy ? () => _submit(register: true) : null,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: valid && !_busy ? () => _submit(register: false) : null,
              child: const Text(
                '已有在线账号？登录并绑定',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
