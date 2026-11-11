import 'package:flutter/widgets.dart';

import 'adaptive_breakpoints.dart';

/// 宽屏限宽居中；窄屏透传 child。
class AdaptiveContentColumn extends StatelessWidget {
  const AdaptiveContentColumn({
    super.key,
    required this.child,
    this.forceClamp = false,
  });

  final Widget child;

  /// 壳已决定出导航轨时，剩余宽度经常小于 [kAdaptiveRailMinWidth]，
  /// 仍要把内容限制到 [kAdaptiveContentMaxWidth]。
  final bool forceClamp;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final clamp =
            forceClamp || constraints.maxWidth >= kAdaptiveRailMinWidth;
        if (!clamp) {
          return child;
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kAdaptiveContentMaxWidth,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
