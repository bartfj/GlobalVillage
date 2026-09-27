import 'package:english_village/features/lesson/dialogue_script.dart';
import 'package:english_village/features/lesson/widgets/dialogue_performance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all units have three valid dialogue lines', () async {
    for (var i = 1; i <= 16; i++) {
      final script = await DialogueScript.load('u$i');
      expect(script, isNotNull);
      expect(script!.lines.length, 3);
      for (final line in script.lines) {
        expect(line.speaker, inInclusiveRange(0, 1));
        expect(line.english.trim(), isNotEmpty);
        expect(line.chinese.trim(), isNotEmpty);
      }
    }
  });

  testWidgets('dialogue can be skipped without waiting for playback', (
    tester,
  ) async {
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialoguePerformance(
            unitId: 'u1',
            unitTitle: '问候与自我介绍',
            onFinished: () => finished++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('跳过'));
    expect(finished, 1);
    await tester.pump(const Duration(seconds: 20));
    expect(finished, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialogue advances through lines and finishes automatically', (
    tester,
  ) async {
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialoguePerformance(
            unitId: 'u1',
            unitTitle: '问候与自我介绍',
            onFinished: () => finished++,
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await DialogueScript.load('u1');
    });
    await tester.pump();
    expect(find.text("Hi! My name is Mia. What's your name?"), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text("I'm Leo. Nice to meet you, Mia!"), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Nice to meet you too, Leo!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(finished, 1);
    expect(tester.takeException(), isNull);
  });
}
