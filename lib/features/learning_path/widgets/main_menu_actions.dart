import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../debug_jump_dialog.dart';

/// 关于弹窗：展示软件版本等信息
void showMainMenuAbout(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.school, color: AppColors.green, size: 32),
          ),
          const SizedBox(height: 12),
          Text('地球村', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          GestureDetector(
            onLongPress: () {
              Navigator.of(dialogContext).pop();
              showDebugJumpMenu(
                context,
                ref,
                onSkipCurrentLesson: () =>
                    confirmSkipCurrentLesson(context, ref),
              );
            },
            child: Text(
              '版本 $kAppVersion',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '闯关学习实用英语',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('知道了', style: TextStyle(color: AppColors.green)),
        ),
      ],
    ),
  );
}

void confirmSkipCurrentLesson(BuildContext context, WidgetRef ref) {
  final lesson = ref.read(progressRepositoryProvider)?.currentLesson;
  if (lesson == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('没有可跳过的关卡')));
    return;
  }
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('跳过当前关卡？'),
      content: Text('将跳过「${lesson.title}」并解锁下一关。该关得分记为 0，之后仍可重新学习。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            final skipped = await ref
                .read(progressRepositoryProvider)
                ?.skipCurrentLesson();
            if (skipped == null) return;
            ref.read(progressRevisionProvider.notifier).state++;
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('已跳过「${skipped.title}」')));
            }
          },
          child: const Text('确认跳过', style: TextStyle(color: AppColors.red)),
        ),
      ],
    ),
  );
}

/// 备份 / 恢复：同一对话框内导出备份码或粘贴恢复
Future<void> showMainMenuBackupRestore(
  BuildContext context,
  WidgetRef ref,
) async {
  final auth = ref.read(authProvider);
  String? exportCode;
  String? exportHint;
  if (auth.isGuest) {
    exportHint = '游客数据不支持导出备份，请先注册账号。仍可粘贴备份码恢复其他账号。';
  } else {
    exportCode = await ref.read(backupServiceProvider).exportBackup();
    if (!context.mounted) return;
    if (exportCode == null) {
      exportHint = '备份失败：未找到当前账号。仍可粘贴备份码尝试恢复。';
    }
  }
  if (!context.mounted) return;

  final controller = TextEditingController();
  String? error;
  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('备份 / 恢复', style: TextStyle(fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '导出备份',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 6),
              if (exportCode case final code?) ...[
                const Text(
                  '复制保存以下备份码，换设备时可在下方粘贴恢复。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      code,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('备份码已复制到剪贴板')),
                        );
                      }
                    },
                    child: const Text(
                      '复制备份码',
                      style: TextStyle(color: AppColors.green),
                    ),
                  ),
                ),
              ] else
                Text(
                  exportHint ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text(
                '恢复数据',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                '粘贴备份码，恢复对应账号与学习进度（同名账号将被覆盖）。',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '粘贴备份码',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    error!,
                    style: const TextStyle(fontSize: 13, color: AppColors.red),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) {
                setState(() => controller.text = data!.text!);
              }
            },
            child: const Text('粘贴', style: TextStyle(color: AppColors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '关闭',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final result = await ref
                  .read(backupServiceProvider)
                  .importBackup(controller.text);
              if (!context.mounted) return;
              if (result != null) {
                setState(() => error = result);
                return;
              }
              final nickname = ref.read(userStoreProvider).currentSession!;
              await ref.read(authProvider.notifier).restoreSession(nickname);
              ref.read(selectedTrackProvider.notifier).reload();
              ref.read(progressRevisionProvider.notifier).state++;
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('已恢复账号 $nickname 的数据')));
              }
            },
            child: const Text('恢复', style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    ),
  );
}

/// 退出登录确认框
void confirmMainMenuLogout(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('退出当前账号？', style: TextStyle(fontSize: 17)),
      content: const Text(
        '退出后可切换其他账号或以游客身份学习，各账号进度互相保留。',
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            '取消',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(authProvider.notifier).logout();
          },
          child: const Text('退出', style: TextStyle(color: AppColors.red)),
        ),
      ],
    ),
  );
}
