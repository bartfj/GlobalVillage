import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:english_village/core/services/sanskrit_audio_service.dart';
import 'package:english_village/data/models/sanskrit_sound.dart';
import 'package:english_village/features/sanskrit_audio/sanskrit_audio_page.dart';
import 'package:english_village/features/sanskrit_audio/sanskrit_audio_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_overrides.dart';

class _Audio implements SanskritAudioService {
  final calls = <(String, double, int)>[];
  SanskritPlaybackResult result = SanskritPlaybackResult.completed;
  Completer<SanskritPlaybackResult>? pending;
  int stops = 0;

  @override
  Future<SanskritPlaybackResult> play(
    SanskritSound sound, {
    double rate = 1,
    int repetitions = 1,
  }) async {
    calls.add((sound.id, rate, repetitions));
    return pending?.future ?? result;
  }

  @override
  Future<void> stop() async {
    stops++;
    final p = pending;
    if (p != null && !p.isCompleted) {
      p.complete(SanskritPlaybackResult.cancelled);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final catalog = SanskritSoundCatalog.fromJson(
    jsonDecode(File('assets/practice/sanskritSounds.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  Future<void> show(
    WidgetTester tester,
    _Audio audio, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uiStringsOverride,
          sanskritSoundCatalogProvider.overrideWith((ref) async => catalog),
          sanskritAudioServiceProvider.overrideWithValue(audio),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const SanskritAudioPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'phone layout and slow/repeated playback use the selected letter',
    (tester) async {
      final audio = _Audio();
      await show(tester, audio, scale: 1.3);
      expect(find.text('梵文发音'), findsOneWidget);
      await tester.tap(find.text('慢速 0.75×'));
      await tester.tap(find.text('重复 3 次'));
      await tester.tap(find.byKey(const ValueKey('sound-aa')));
      await tester.pumpAndSettle();
      expect(audio.calls, [('aa', .75, 3)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed playback shows recovery and source attribution is visible',
    (tester) async {
      final audio = _Audio()..result = SanskritPlaybackResult.failed;
      await show(tester, audio);
      await tester.tap(find.byKey(const ValueKey('sound-a')));
      await tester.pumpAndSettle();
      expect(find.textContaining('音频播放失败'), findsOneWidget);
      await tester.tap(find.byTooltip('音频来源'));
      await tester.pumpAndSettle();
      expect(find.text(catalog.source['pageUrl'] as String), findsOneWidget);
      expect(find.textContaining('已包含在安装包中'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('included recordings need no download and leaving stops playback', (
    tester,
  ) async {
    final audio = _Audio();
    await show(tester, audio);
    expect(find.text('录音已内置，无需下载'), findsOneWidget);
    expect(find.text('下载全部 · 约 300 KB'), findsNothing);
    audio.pending = Completer<SanskritPlaybackResult>();
    await tester.tap(find.byKey(const ValueKey('sound-a')));
    await tester.pump();
    expect(find.text('停止播放'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(audio.stops, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
