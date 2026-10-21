import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/services/sanskrit_audio_service.dart';
import '../../data/models/sanskrit_sound.dart';
import '../../data/repositories/sanskrit_audio_repository.dart';

final sanskritSoundCatalogProvider = FutureProvider<SanskritSoundCatalog>((
  ref,
) async {
  final json = await rootBundle.loadString(
    'assets/practice/sanskritSounds.json',
  );
  return SanskritSoundCatalog.fromJson(
    jsonDecode(json) as Map<String, dynamic>,
  );
});

final sanskritAudioRepositoryProvider =
    FutureProvider.autoDispose<SanskritAudioRepository>((ref) async {
      final client = http.Client();
      ref.onDispose(client.close);
      final support = await getApplicationSupportDirectory();
      return SanskritAudioRepository(
        root: Directory('${support.path}/sanskrit_audio_v1'),
        client: client,
      );
    });

final sanskritAudioServiceProvider = Provider.autoDispose<SanskritAudioService>(
  (ref) {
    final service = SanskritAudioService(
      repository: ref.watch(sanskritAudioRepositoryProvider.future),
    );
    ref.onDispose(service.dispose);
    return service;
  },
);
