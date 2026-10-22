import 'package:english_village/app/providers.dart';
import 'package:english_village/core/services/phonetic_lookup_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/features/lesson/widgets/tappable_phonetic_text.dart';
import 'package:english_village/features/lesson/widgets/translate_choice_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'ui_test_overrides.dart';

const _sentence = 'Could I speak to the pharmacist?';

const _exercise = Exercise(
  id: 'u53l1e1',
  type: ExerciseType.translateChoice,
  prompt: '我可以和药剂师说话吗？',
  sentence: _sentence,
  options: [
    _sentence,
    'Of course, what do you need?',
    'I need advice about this medicine.',
  ],
  answer: _sentence,
);

void main() {
  late PhoneticLookupService service;

  setUp(() {
    service = PhoneticLookupService(
      client: MockClient((request) async => http.Response('nope', 500)),
      localIpa: {'could': '/kʊd/', 'pharmacist': '/ˈfɑːrməsɪst/'},
      localGloss: {'could': 'aux. 能；可以', 'pharmacist': 'n. 药剂师'},
    );
  });

  tearDown(() {
    dismissPhoneticBubble();
    service.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    required bool checked,
    required String? selected,
    required ValueChanged<String> onChanged,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneticLookupProvider.overrideWith((ref) => service),
          uiStringsOverride,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: TranslateChoiceWidget(
                exercise: _exercise,
                enabled: !checked,
                selected: selected,
                checked: checked,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('long press looks up the pressed word and tap selects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? selected;
    await pump(
      tester,
      checked: false,
      selected: null,
      onChanged: (value) => selected = value,
    );

    await tester.tap(find.text('pharmacist?'));
    await tester.pump();
    expect(selected, _sentence);
    expect(find.text('pharmacist'), findsNothing);

    await tester.longPress(find.text('pharmacist?'));
    await tester.pump();
    await tester.pump();

    expect(find.text('pharmacist'), findsOneWidget);
    expect(find.text('\u2066/ˈfɑːrməsɪst/\u2069'), findsOneWidget);
    expect(find.text('could'), findsNothing);
  });

  testWidgets('after check, tap looks up the pressed word', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var changed = false;
    await pump(
      tester,
      checked: true,
      selected: _sentence,
      onChanged: (_) => changed = true,
    );

    await tester.tap(find.text('pharmacist?'));
    await tester.pump();
    await tester.pump();

    expect(changed, isFalse);
    expect(find.text('pharmacist'), findsOneWidget);
    expect(find.text('\u2066/ˈfɑːrməsɪst/\u2069'), findsOneWidget);
    expect(find.text('could'), findsNothing);
  });
}
