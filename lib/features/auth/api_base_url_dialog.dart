import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/sources/api_base_url.dart';

/// 打开服务地址配置。保存后立刻影响之后的登录、注册和同步。
Future<void> showApiBaseUrlDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const ApiBaseUrlDialog(),
  );
}

class ApiBaseUrlDialog extends ConsumerStatefulWidget {
  const ApiBaseUrlDialog({super.key});

  @override
  ConsumerState<ApiBaseUrlDialog> createState() => _ApiBaseUrlDialogState();
}

class _ApiBaseUrlDialogState extends ConsumerState<ApiBaseUrlDialog> {
  late final TextEditingController _address;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: ref.read(apiBaseUrlProvider));
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _save(String raw) async {
    if (_busy) return;
    final normalized = normalizeApiBaseUrl(raw);
    if (normalized == null) {
      setState(() => _error = '请输入 http 或 https 地址');
      return;
    }

    final next = normalized.isEmpty ? kApiBaseUrl : normalized;
    final current = ref.read(apiBaseUrlProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    if (next != current && ref.read(authProvider).isOnline) {
      await ref.read(authProvider.notifier).logout();
    }
    await ref
        .read(apiBaseUrlProvider.notifier)
        .apply(next == kApiBaseUrl ? null : next);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(authProvider).isOnline;
    return AlertDialog(
      title: const Text('服务地址'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '在线账号的登录、注册和同步都连接这个地址。只写主机和端口时会自动加上 /v1。',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: '地址',
              hintText: 'http://192.168.1.8:8787',
              errorText: _error,
            ),
            onSubmitted: _save,
          ),
          if (online) ...[
            const SizedBox(height: 8),
            const Text(
              '改成另一个地址后，会退出当前在线账号。',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => _save(''),
          child: const Text('恢复默认'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _busy ? null : () => _save(_address.text),
          child: Text(_busy ? '保存中…' : '保存'),
        ),
      ],
    );
  }
}

/// 显示当前服务地址，点击后打开配置。
class ApiBaseUrlButton extends ConsumerWidget {
  const ApiBaseUrlButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(apiBaseUrlProvider);
    return TextButton(
      onPressed: () => showApiBaseUrlDialog(context),
      child: Text(
        '服务地址 $url',
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
