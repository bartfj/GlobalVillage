import 'package:english_village/app/providers.dart';
import 'package:english_village/core/services/tts_service.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/features/skill_practice/english_tts_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_overrides.dart';

class _RecordingTts implements TtsService {
  _RecordingTts({this.result = true});

  final bool result;
  final spoken = <String>[];

  @override
  Future<bool> speak(
    String text, {
    LearningLanguage language = LearningLanguage.english,
  }) async {
    spoken.add(text);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpButton(WidgetTester tester, TtsService tts) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ttsServiceProvider.overrideWithValue(tts),
        uiStringsOverride,
      ],
      child: const MaterialApp(
        home: Scaffold(body: EnglishTtsButton(text: 'Hold the pose.')),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('speaker button reads the english text', (tester) async {
    final tts = _RecordingTts();
    await _pumpButton(tester, tts);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tts.spoken, ['Hold the pose.']);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('failed playback shows a hint and restores the button', (
    tester,
  ) async {
    final tts = _RecordingTts(result: false);
    await _pumpButton(tester, tts);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    // 让提示自己消失，避免测试结束时留下定时器。
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
  });
}
