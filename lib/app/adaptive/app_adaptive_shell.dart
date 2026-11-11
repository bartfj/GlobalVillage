import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/skill_practice.dart';
import '../providers.dart';
import 'adaptive_breakpoints.dart';
import 'adaptive_content_column.dart';
import 'adaptive_nav_destination.dart';

/// 当前语言第一个专项练习的路由。练习轨的 `location` 只是占位。
String practiceLocation(WidgetRef ref) {
  final skills = SkillPracticeKind.forLanguage(
    ref.read(selectedTrackProvider).language,
  );
  return '/practice/${skills.first.name}';
}

/// 宽屏左侧导航轨；窄屏只渲染内容列。
class AppAdaptiveShell extends ConsumerWidget {
  const AppAdaptiveShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = showAdaptiveRail(constraints.maxWidth);
        final body = AdaptiveContentColumn(child: child);
        if (!wide) {
          return body;
        }

        final matched = GoRouterState.of(context).matchedLocation;
        final s = ref.watch(stringsProvider);
        // visible 回调只 read；这里 watch 以便切换学习语言时重建轨。
        ref.watch(selectedTrackProvider);
        final destinations = buildAdaptiveNavDestinations()
            .where((d) => d.visible(ref))
            .toList();
        final selected = destinations.indexWhere((d) => d.matches(matched));

        return Row(
          children: [
            NavigationRail(
              scrollable: true,
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (i) {
                final d = destinations[i];
                final loc = d.id == 'practice'
                    ? practiceLocation(ref)
                    : d.location;
                if (loc != matched) {
                  context.go(loc);
                }
              },
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label(s)),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
