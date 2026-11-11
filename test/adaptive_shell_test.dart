import 'package:english_village/app/adaptive/adaptive_breakpoints.dart';
import 'package:english_village/app/adaptive/adaptive_content_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('showAdaptiveRail uses 900 breakpoint', () {
    expect(showAdaptiveRail(899), isFalse);
    expect(showAdaptiveRail(900), isTrue);
    expect(showAdaptiveRail(1024), isTrue);
  });

  testWidgets('AdaptiveContentColumn limits width on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveContentColumn(
            child: SizedBox(width: double.infinity, height: 40, key: Key('inner')),
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.byKey(const Key('inner')));
    expect(box.size.width, lessThanOrEqualTo(kAdaptiveContentMaxWidth));
  });

  testWidgets('AdaptiveContentColumn does not clamp on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveContentColumn(
            child: SizedBox(width: double.infinity, height: 40, key: Key('inner')),
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.byKey(const Key('inner')));
    expect(box.size.width, closeTo(390, 0.5));
  });
}
