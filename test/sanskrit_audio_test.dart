import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:english_village/core/services/sanskrit_audio_service.dart';
import 'package:english_village/data/models/sanskrit_sound.dart';
import 'package:english_village/data/repositories/sanskrit_audio_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  group('verified offline cache', () {
    late Directory root;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('sanskrit-cache-');
    });
    tearDown(() => root.delete(recursive: true));

    test(
      'coalesces downloads, survives network loss, repairs corrupt cache',
      () async {
        var requests = 0;
        var online = true;
        final client = MockClient((request) async {
          requests++;
          if (!online) throw const SocketException('offline');
          return http.Response.bytes(
            _bytes,
            200,
            headers: {'content-type': 'audio/mpeg'},
          );
        });
        addTearDown(client.close);
        final repo = SanskritAudioRepository(root: root, client: client);
        final sound = _sound('a');
        final paths = await Future.wait([
          repo.fileFor(sound),
          repo.fileFor(sound),
        ]);
        expect(requests, 1);
        expect(paths[0], paths[1]);
        expect(await repo.cachedIds([sound]), {'a'});
        online = false;
        expect(await repo.fileFor(sound), paths[0]);
        expect(requests, 1);
        await File(paths[0]).writeAsString('broken');
        expect(await repo.cachedIds([sound]), isEmpty);
        await expectLater(repo.fileFor(sound), throwsA(isA<SocketException>()));
        online = true;
        expect(await repo.fileFor(sound), paths[0]);
        expect(await File(paths[0]).readAsBytes(), _bytes);
        expect(root.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
      },
    );

    for (final scenario in ['html', 'wrong-hash', 'not-found', 'too-large']) {
      test('rejects $scenario without marking a file offline', () async {
        final client = MockClient(
          (_) async => switch (scenario) {
            'html' => http.Response(
              '<html>error</html>',
              200,
              headers: {'content-type': 'text/html'},
            ),
            'wrong-hash' => http.Response.bytes(
              List.filled(_bytes.length, 0),
              200,
              headers: {'content-type': 'audio/mpeg'},
            ),
            'not-found' => http.Response('missing', 404),
            _ => http.Response.bytes(
              [..._bytes, 0],
              200,
              headers: {'content-type': 'audio/mpeg'},
            ),
          },
        );
        addTearDown(client.close);
        final repo = SanskritAudioRepository(root: root, client: client);
        await expectLater(repo.fileFor(_sound('a')), throwsFormatException);
        expect(await repo.cachedIds([_sound('a')]), isEmpty);
        expect(root.listSync(), isEmpty);
      });
    }
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
