import 'package:flutter/widgets.dart';

import 'adaptive_breakpoints.dart';

/// 宽屏限宽居中；窄屏透传 child。
class AdaptiveContentColumn extends StatelessWidget {
  const AdaptiveContentColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kAdaptiveRailMinWidth) {
          return child;
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kAdaptiveContentMaxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
