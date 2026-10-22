import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:english_village/core/services/sanskrit_audio_service.dart';
import 'package:english_village/data/models/sanskrit_sound.dart';
import 'package:english_village/data/repositories/sanskrit_audio_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final _bytes = utf8.encode('ID3 test recording');

SanskritSound _sound(String id) => SanskritSound(
  id: id,
  devanagari: id == 'a' ? 'अ' : 'आ',
  iast: id == 'a' ? 'a' : 'ā',
  group: 'vowel',
  description: '元音',
  hint: '比较长度',
  url: Uri.parse('https://www.arshavidya.org.uk/a/mp3s/sounds/vowel-$id.mp3'),
  sha256: sha256.convert(_bytes).toString(),
  byteLength: _bytes.length,
);

class _Player implements SanskritSoundPlayer {
  final calls = <(String, double)>[];
  final started = Completer<void>();
  final bool hold;
  Completer<void>? _finished;
  bool disposed = false;
  _Player({this.hold = false});

  @override
  Future<void> play(String path, double rate) async {
    calls.add((path, rate));
    if (!started.isCompleted) started.complete();
    if (hold) {
      _finished = Completer<void>();
      await _finished!.future;
    }
  }

  @override
  Future<void> stop() async {
    final finished = _finished;
    if (finished != null && !finished.isCompleted) finished.complete();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
  }
}

class _PendingRepository implements SanskritAudioRepository {
  final first = Completer<String>();
  @override
  Future<String> fileFor(SanskritSound sound) =>
      sound.id == 'a' ? first.future : Future.value('/audio/${sound.id}.mp3');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'catalog preserves distinct letter pairs, provenance and pending review',
    () {
      final json =
          jsonDecode(
                File('assets/practice/sanskritSounds.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final catalog = SanskritSoundCatalog.fromJson(json);
      expect(catalog.sounds.length, 48);
      expect(catalog.sounds.where((s) => s.group == 'vowel').length, 13);
      expect(catalog.sounds.map((s) => s.url).toSet().length, 48);
      expect(catalog.source['reviewStatus'], 'pendingProfessionalReview');
      expect(
        catalog.source['licenseStatus'],
        'redistributionPermissionUnconfirmed',
      );
      for (final pair in [('a', 'aa'), ('ka', 'kha'), ('ta', 'tta')]) {
        final a = catalog.sounds.firstWhere((s) => s.id == pair.$1);
        final b = catalog.sounds.firstWhere((s) => s.id == pair.$2);
        expect(a.devanagari, isNot(b.devanagari));
        expect(a.iast, isNot(b.iast));
        expect(a.sha256, isNot(b.sha256));
      }
      final invalid = Map<String, dynamic>.from(
        (json['sounds'] as List).first as Map,
      )..['id'] = '../escape';
      expect(() => SanskritSound.fromJson(invalid), throwsFormatException);
      invalid['id'] = 'a';
      invalid['url'] = 'http://untrusted.test/a.mp3';
      expect(() => SanskritSound.fromJson(invalid), throwsFormatException);
    },
  );

  group('bundled recordings', () {
    late Directory root;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('sanskrit-cache-');
    });
    tearDown(() => root.delete(recursive: true));

    test('reads the packaged file once and reuses the checked copy', () async {
      var reads = 0;
      final repo = SanskritAudioRepository(
        root: root,
        readBundled: (sound) async {
          reads++;
          return _bytes;
        },
      );
      final sound = _sound('a');
      final paths = await Future.wait([
        repo.fileFor(sound),
        repo.fileFor(sound),
      ]);
      expect(reads, 1);
      expect(paths[0], paths[1]);
      expect(await repo.cachedIds([sound]), {'a'});
      expect(await repo.fileFor(sound), paths[0]);
      expect(reads, 1);
      await File(paths[0]).writeAsString('broken');
      expect(await repo.cachedIds([sound]), isEmpty);
      expect(await repo.fileFor(sound), paths[0]);
      expect(await File(paths[0]).readAsBytes(), _bytes);
      expect(root.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
    });

    test('rejects a bundled file that does not match the catalog', () async {
      final repo = SanskritAudioRepository(
        root: root,
        readBundled: (_) async => List.filled(_bytes.length, 0),
      );
      await expectLater(repo.fileFor(_sound('a')), throwsFormatException);
      expect(await repo.cachedIds([_sound('a')]), isEmpty);
      expect(root.listSync(), isEmpty);
    });

    test('packaged files match the catalog checksums', () {
      final json =
          jsonDecode(
                File('assets/practice/sanskritSounds.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final catalog = SanskritSoundCatalog.fromJson(json);
      for (final sound in catalog.sounds) {
        final file = File('assets/practice/sanskrit_audio/${sound.id}.mp3');
        final bytes = file.readAsBytesSync();
        expect(bytes.length, sound.byteLength, reason: sound.id);
        expect(sha256.convert(bytes).toString(), sound.sha256, reason: sound.id);
      }
    });
  });

  group('playback sequence', () {
    test('uses requested rate and repeats exactly three times', () async {
      final repo = _PendingRepository();
      final player = _Player();
      final service = SanskritAudioService(
        repository: Future.value(repo),
        player: player,
      );
      addTearDown(service.dispose);
      expect(
        await service.play(_sound('aa'), rate: .75, repetitions: 3),
        SanskritPlaybackResult.completed,
      );
      expect(player.calls, List.filled(3, ('/audio/aa.mp3', .75)));
    });

    test(
      'switching letters cancels a pending download without late playback',
      () async {
        final repo = _PendingRepository();
        final player = _Player();
        final service = SanskritAudioService(
          repository: Future.value(repo),
          player: player,
        );
        addTearDown(service.dispose);
        final old = service.play(_sound('a'));
        await Future<void>.delayed(Duration.zero);
        final next = service.play(_sound('aa'));
        expect(await old, SanskritPlaybackResult.cancelled);
        expect(await next, SanskritPlaybackResult.completed);
        repo.first.complete('/audio/a.mp3');
        await Future<void>.delayed(Duration.zero);
        expect(player.calls, [('/audio/aa.mp3', 1.0)]);
      },
    );

    test(
      'stop interrupts playback and dispose prevents any future start',
      () async {
        final player = _Player(hold: true);
        final service = SanskritAudioService(
          repository: Future.value(_PendingRepository()),
          player: player,
        );
        final active = service.play(_sound('aa'), repetitions: 3);
        await player.started.future;
        await service.stop();
        expect(await active, SanskritPlaybackResult.cancelled);
        expect(player.calls.length, 1);
        await service.dispose();
        expect(player.disposed, isTrue);
        expect(
          await service.play(_sound('aa')),
          SanskritPlaybackResult.cancelled,
        );
        expect(player.calls.length, 1);
      },
    );
  });
}
