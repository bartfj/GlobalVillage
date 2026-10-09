import 'package:english_village/app/theme.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/features/lesson/widgets/match_pairs_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _pairs = [
  MatchPair(left: '你好', right: 'Hello.'),
  MatchPair(left: '早上好', right: 'Good morning.'),
  MatchPair(left: '下午好', right: 'Good afternoon.'),
  MatchPair(left: '再见', right: 'Goodbye.'),
];

Exercise _exercise() {
  return Exercise(
    id: 'u1l1e3',
    type: ExerciseType.matchPairs,
    prompt: '把中文和英文连起来',
    sentence: 'Hello.',
    options: const [],
    answer: MatchPair.encode(_pairs),
    pairs: _pairs,
  );
}

Widget _host({required Widget child}) {
  return ProviderScope(
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: child),
    ),
  );
}

List<String> _rightOrder(WidgetTester tester) {
  const prefix = 'match-right:';
  return [
    for (final element in find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith(prefix);
    }).evaluate())
      ((element.widget.key as ValueKey<String>).value).substring(prefix.length),
  ];
}

void main() {
  test('MatchPair.encode 按 left 排序拼接', () {
    expect(
      MatchPair.encode(_pairs).split('|'),
      [
        '下午好=Good afternoon.',
        '你好=Hello.',
        '再见=Goodbye.',
        '早上好=Good morning.',
      ],
    );
    expect(
      MatchPair.formatForDisplay(MatchPair.encode(_pairs)),
      '下午好 — Good afternoon.\n你好 — Hello.\n再见 — Goodbye.\n早上好 — Good morning.',
    );
  });

  testWidgets('同一题 id 右侧英文顺序稳定', (tester) async {
    Future<List<String>> rightOrder() async {
      await tester.pumpWidget(
        _host(
          child: MatchPairsWidget(
            exercise: _exercise(),
            enabled: true,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      return _rightOrder(tester);
    }

    final first = await rightOrder();
    await tester.pumpWidget(const SizedBox.shrink());
    final second = await rightOrder();
    expect(first, hasLength(4));
    expect(first.toSet(), {for (final pair in _pairs) pair.right});
    expect(first, second);
  });

  testWidgets('未配完不提交答案，配齐后输出规范化字符串', (tester) async {
    var latest = 'unset';
    final exercise = _exercise();
    await tester.pumpWidget(
      _host(
        child: MatchPairsWidget(
          exercise: exercise,
          enabled: true,
          onChanged: (value) => latest = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tapChip(String prefix, String label) async {
      await tester.tap(find.byKey(ValueKey('$prefix$label')));
    }

    await tapChip('match-left:', '你好');
    await tapChip('match-right:', 'Hello.');
    await tester.pump();
    expect(latest, isEmpty);

    await tapChip('match-left:', '早上好');
    await tapChip('match-right:', 'Good morning.');
    await tapChip('match-left:', '下午好');
    await tapChip('match-right:', 'Good afternoon.');
    await tapChip('match-left:', '再见');
    await tapChip('match-right:', 'Goodbye.');
    await tester.pump();
    expect(latest, exercise.answer);

    await tapChip('match-left:', '你好');
    await tester.pump();
    expect(latest, isEmpty);
  });
}
