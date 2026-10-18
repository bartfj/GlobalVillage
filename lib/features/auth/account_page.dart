import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/sources/user_store.dart';
import 'widgets/auth_text_field.dart';

/// 账号资料：在线可改昵称；本地昵称与注册时间只读。
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _nickname = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _nickname.text = _currentNickname();
    _loaded = true;
    _nickname.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final authState = ref.read(authProvider);
    final notifier = ref.read(authProvider.notifier);
    if (authState.isOnline) {
      if (authState.accessToken == null) {
        await notifier.refreshAccessToken();
      }
      await notifier.refreshProfile();
    }
    if (!mounted) return;
    _nickname.text = _currentNickname();
    setState(() => _loaded = true);
  }

  String _currentNickname() {
    final authState = ref.read(authProvider);
    if (authState.isOnline) return authState.displayName ?? '';
    final user = ref.read(userStoreProvider).getUser(authState.userKey ?? '');
    return user?.nickname ?? authState.userKey ?? '';
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(authProvider.notifier)
        .updateDisplayName(_nickname.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final store = ref.watch(userStoreProvider);
    final online = authState.isOnline;
    final createdAt = online
        ? store.currentCreatedAt
        : store.getUser(authState.userKey ?? '')?.createdAt;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('账号资料'),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(28),
                children: [
                  if (online)
                    AuthTextField(
                      label: '昵称（2-12 个字符）',
                      controller: _nickname,
                      errorText: _error,
                    )
                  else
                    _InfoRow(label: '昵称', value: _nickname.text),
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: '登录方式',
                    value: online ? _loginIdentity(store) : '仅保存在本机',
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: '注册时间',
                    value: createdAt == null ? '—' : _formatTime(createdAt),
                  ),
                  if (online) ...[
                    const SizedBox(height: 28),
                    PushableButton(
                      label: _busy ? '保存中…' : '保存',
                      onPressed: _busy || _nickname.text.trim().isEmpty
                          ? null
                          : _save,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

String _loginIdentity(UserStore store) {
  final parts = <String>[
    if (store.currentPhone != null) _maskPhone(store.currentPhone!),
    if (store.currentEmail != null) _maskEmail(store.currentEmail!),
  ];
  if (parts.isEmpty) return '在线账号';
  return parts.join(' · ');
}

String _maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  return '${email.substring(0, 1)}***${email.substring(at)}';
}

String _maskPhone(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('86') && digits.length > 11) {
    digits = digits.substring(2);
  }
  if (digits.length < 7) return phone;
  return '${digits.substring(0, 3)}****${digits.substring(digits.length - 4)}';
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
