import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:english_village/core/services/sanskrit_audio_service.dart';
import 'package:english_village/data/models/audio_clip.dart';
import 'package:english_village/data/models/skill_practice.dart';
import 'package:english_village/data/models/yoga_term_audio.dart';
import 'package:english_village/data/repositories/sanskrit_audio_repository.dart';
import 'package:english_village/features/skill_practice/yoga_audio_button.dart';
import 'package:english_village/features/skill_practice/yoga_audio_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_overrides.dart';

YogaTermAudioCatalog _catalog() {
  final raw = File('assets/practice/sanskritYogaAudio.json').readAsStringSync();
  return YogaTermAudioCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

class _Player implements SanskritSoundPlayer {
  final calls = <String>[];

  @override
  Future<void> play(String path, double rate) async => calls.add(path);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _Repository implements SanskritAudioRepository {
  @override
  Future<String> fileFor(AudioClip clip) async => '/audio/${clip.id}.mp3';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HangingRepository implements SanskritAudioRepository {
  @override
  Future<String> fileFor(AudioClip clip) => Completer<String>().future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog matches the packaged recordings and yoga bank', () {
    final catalog = _catalog();
    expect(catalog.terms.length, 64);
    expect(catalog.source['reviewStatus'], 'syntheticReference');

    for (final term in catalog.terms.values) {
      final file = File('assets/practice/sanskrit_yoga_audio/${term.id}.mp3');
      final bytes = file.readAsBytesSync();
      expect(bytes.length, term.byteLength, reason: term.id);
      expect(sha256.convert(bytes).toString(), term.sha256, reason: term.id);
    }

    final bank = SkillPracticeBank.fromJson(
      jsonDecode(File('assets/practice/sanskritYoga.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    expect(bank.exercises.length, 128);
    expect(
      bank.exercises.map((e) => e.audioId!).toSet(),
      catalog.terms.keys.toSet(),
    );
    for (final exercise in bank.exercises) {
      expect(exercise.audioId, isNotNull, reason: exercise.id);
      expect(
        catalog.terms.containsKey(exercise.audioId),
        isTrue,
        reason: exercise.id,
      );
    }
    for (var i = 0; i < bank.exercises.length; i += 2) {
      expect(bank.exercises[i].audioId, bank.exercises[i + 1].audioId);
    }
    for (var i = 80; i < bank.exercises.length; i += 2) {
      final reading = bank.exercises[i];
      final term = catalog.terms[reading.audioId]!;
      expect(term.devanagari, reading.support, reason: term.id);
      expect(term.iast, reading.answer, reason: term.id);
    }
  });

  test('an expanded term loads offline from the asset bundle', () async {
    final root = await Directory.systemTemp.createTemp('yoga_audio_test');
    addTearDown(() => root.delete(recursive: true));
    final catalog = YogaTermAudioCatalog.fromJson(
      jsonDecode(
            await rootBundle.loadString(
              'assets/practice/sanskritYogaAudio.json',
            ),
          )
          as Map<String, dynamic>,
    );
    final term = catalog.terms['puraka']!;
    final repository = SanskritAudioRepository(
      root: root,
      readBundled: (clip) async {
        final bytes = await rootBundle.load(
          'assets/practice/sanskrit_yoga_audio/${clip.id}.mp3',
        );
        return bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      },
    );

    final file = File(await repository.fileFor(term));
    expect(sha256.convert(await file.readAsBytes()).toString(), term.sha256);
  });

  test('rejects malformed entries', () {
    final raw =
        jsonDecode(
              File('assets/practice/sanskritYogaAudio.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final invalid = Map<String, dynamic>.from(
      (raw['terms'] as List).first as Map,
    )..['id'] = '../escape';
    expect(() => YogaTermAudio.fromJson(invalid), throwsFormatException);
    invalid['id'] = 'namaste';
    invalid['sha256'] = 'not-a-checksum';
    expect(() => YogaTermAudio.fromJson(invalid), throwsFormatException);
  });

  testWidgets('audio button plays the bundled term', (tester) async {
    final player = _Player();
    final service = SanskritAudioService(
      repository: Future.value(_Repository()),
      player: player,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          yogaTermAudioCatalogProvider.overrideWith((ref) async => _catalog()),
          yogaAudioServiceProvider.overrideWith((ref) => service),
          uiStringsOverride,
        ],
        child: const MaterialApp(
          home: Scaffold(body: YogaAudioButton(audioId: 'utkatasana')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byTooltip('播放合成参考发音'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(player.calls, ['/audio/utkatasana.mp3']);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('audio button recovers when the recording never resolves', (
    tester,
  ) async {
    final service = SanskritAudioService(
      repository: Future.value(_HangingRepository()),
      player: _Player(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          yogaTermAudioCatalogProvider.overrideWith((ref) async => _catalog()),
          yogaAudioServiceProvider.overrideWith((ref) => service),
          uiStringsOverride,
        ],
        child: const MaterialApp(
          home: Scaffold(body: YogaAudioButton(audioId: 'namaste')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    // 让失败提示自己消失，避免测试结束时留下定时器。
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
  });
}
