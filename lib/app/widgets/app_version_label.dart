import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../data/sources/cloud_auth_api.dart';
import '../theme.dart';

/// 页脚版本号。长按才显示并复制当前 API 基址（隧道地址）。
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _revealApiBase(context),
      child: const Text(
        'v$kAppVersion',
        style: TextStyle(fontSize: 12, color: AppColors.lockedDark),
      ),
    );
  }

  Future<void> _revealApiBase(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: kApiBaseUrl));
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('服务地址'),
        content: const SelectableText(kApiBaseUrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了', style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    );
  }
}
