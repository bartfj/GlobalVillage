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

void main() {
  test('catalog matches the packaged recordings and yoga bank', () {
    final catalog = _catalog();
    expect(catalog.terms.length, 20);
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
    expect(bank.exercises.length, 40);
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
          home: Scaffold(body: YogaAudioButton(audioId: 'namaste')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(player.calls, ['/audio/namaste.mp3']);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });
}
