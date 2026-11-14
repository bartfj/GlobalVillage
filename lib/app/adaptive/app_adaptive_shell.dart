import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/skill_practice.dart';
import '../../features/feedback/feedback_dialog.dart';
import '../../features/learning_path/widgets/main_menu_actions.dart';
import '../../features/learning_path/widgets/main_menu_drawer.dart';
import '../providers.dart';
import 'adaptive_breakpoints.dart';
import 'adaptive_content_column.dart';

/// 当前语言第一个专项练习的路由。练习轨的 `location` 只是占位。
String practiceLocation(WidgetRef ref) {
  final skills = SkillPracticeKind.forLanguage(
    ref.read(selectedTrackProvider).language,
  );
  return '/practice/${skills.first.name}';
}

/// 宽屏复用手机完整主菜单，右侧页面占满剩余空间。
class AppAdaptiveShell extends ConsumerWidget {
  const AppAdaptiveShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = showAdaptiveRail(constraints.maxWidth);
        if (!wide) {
          return AdaptiveContentColumn(child: child);
        }
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const ValueKey('adaptive-main-menu'),
                width: kAdaptiveMenuWidth,
                child: MainMenuDrawer(
                  persistent: true,
                  onBackupRestore: () =>
                      showMainMenuBackupRestore(context, ref),
                  onFeedback: () => showFeedbackDialog(context, ref),
                  onAbout: () => showMainMenuAbout(context, ref),
                  onLogout: () => confirmMainMenuLogout(context, ref),
                  onLogin: () => context.push('/login'),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
