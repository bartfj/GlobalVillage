import 'dart:convert';
import 'dart:io';

import 'package:english_village/features/lesson/dialogue_script.dart';
import 'package:english_village/features/lesson/widgets/dialogue_performance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 旧版词数估时：音频未完就会切句/结束的那套公式。
Duration _oldEstimate(String english) {
  final words = english.split(RegExp(r'\s+')).length;
  return Duration(milliseconds: (words * 400 + 1400).clamp(3200, 7800));
}

/// 当前超时兜底（与 DialoguePerformance 一致）。
Duration _timeoutEstimate(String english) {
  final words = english.split(RegExp(r'\s+')).length;
  return Duration(milliseconds: (words * 400 + 2000).clamp(4500, 12000));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every dialogue line has a bundled recording', () {
    final raw = File(
      'assets/dialogues/unit_dialogues.json',
    ).readAsStringSync();
    final scripts = jsonDecode(raw) as Map<String, dynamic>;
    for (final entry in scripts.entries) {
      final lines = entry.value;
      if (lines is! List) continue;
      for (var i = 0; i < lines.length; i++) {
        final audio = File('assets/audio/dialogues/${entry.key}_${i + 1}.mp3');
        expect(audio.existsSync(), isTrue, reason: audio.path);
        expect(audio.lengthSync(), greaterThan(0), reason: audio.path);
      }
    }
  });

  test('all units have three valid dialogue lines', () async {
    Future<void> expectUnit(String unitId) async {
      final script = await DialogueScript.load(unitId);
      expect(script, isNotNull, reason: unitId);
      expect(script!.lines.length, 3, reason: unitId);
      for (final line in script.lines) {
        expect(line.speaker, inInclusiveRange(0, 1), reason: unitId);
        expect(line.english.trim(), isNotEmpty, reason: unitId);
        expect(line.chinese.trim(), isNotEmpty, reason: unitId);
      }
    }

    for (var i = 1; i <= 68; i++) {
      await expectUnit('u$i');
    }
    for (var i = 1; i <= 58; i++) {
      await expectUnit('z_u$i');
    }
    for (var i = 1; i <= 16; i++) {
      await expectUnit('i_u$i');
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
    final script = await tester.runAsync(() => DialogueScript.load('u1'));
    await tester.pump();
    expect(find.text("Hi! My name is Mia. What's your name?"), findsOneWidget);

    // 用超时兜底推进（测试环境未必触发 onPlayerComplete）。
    await tester.pump(_timeoutEstimate(script!.lines[0].english));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("I'm Leo. Nice to meet you, Mia!"), findsOneWidget);

    await tester.pump(_timeoutEstimate(script.lines[1].english));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nice to meet you too, Leo!'), findsOneWidget);

    await tester.pump(_timeoutEstimate(script.lines[2].english));
    await tester.pump(const Duration(milliseconds: 600));
    expect(finished, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('last line does not finish at old short estimate', (
    tester,
  ) async {
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialoguePerformance(
            unitId: 'u44',
            unitTitle: '综合表达',
            onFinished: () => finished++,
          ),
        ),
      ),
    );
    final script = await tester.runAsync(() => DialogueScript.load('u44'));
    await tester.pump();
    expect(script, isNotNull);
    expect(script!.lines, hasLength(3));

    // 推进到最后一句。
    await tester.pump(_timeoutEstimate(script.lines[0].english));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(_timeoutEstimate(script.lines[1].english));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(script.lines[2].english), findsOneWidget);
    expect(finished, 0);

    final oldEstimate = _oldEstimate(script.lines[2].english);
    final newTimeout = _timeoutEstimate(script.lines[2].english);
    expect(newTimeout, greaterThan(oldEstimate), reason: '本用例依赖新超时比旧估时更长');

    // 旧公式时长到了仍不应结束（真实 mp3 往往更长）。
    await tester.pump(oldEstimate);
    expect(find.text(script.lines[2].english), findsOneWidget);
    expect(finished, 0);

    // 等到新超时 + 收尾空隙才结束。
    await tester.pump(newTimeout - oldEstimate);
    await tester.pump(const Duration(milliseconds: 600));
    expect(finished, 1);
    expect(tester.takeException(), isNull);
  });
}
