import 'package:english_village/app/theme.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/features/lesson/widgets/word_bank_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_overrides.dart';

void main() {
  testWidgets('词块组件能渲染出词块', (tester) async {
    const exercise = Exercise(
      id: 'u1l1e4',
      type: ExerciseType.wordBank,
      prompt: '早上好！',
      sentence: 'Good morning!',
      options: [],
      answer: 'Good morning!',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [uiStringsOverride],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: WordBankWidget(
              exercise: exercise,
              enabled: true,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('morning!'), findsOneWidget);
  });
}
