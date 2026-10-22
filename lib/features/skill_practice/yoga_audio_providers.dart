import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/sanskrit_audio_service.dart';
import '../../data/models/yoga_term_audio.dart';
import '../../data/repositories/sanskrit_audio_repository.dart';

final yogaTermAudioCatalogProvider = FutureProvider<YogaTermAudioCatalog>((
  ref,
) async {
  final json = await rootBundle.loadString(
    'assets/practice/sanskritYogaAudio.json',
  );
  return YogaTermAudioCatalog.fromJson(
    jsonDecode(json) as Map<String, dynamic>,
  );
});

final yogaAudioRepositoryProvider =
    FutureProvider.autoDispose<SanskritAudioRepository>((ref) async {
      final support = await getApplicationSupportDirectory();
      return SanskritAudioRepository(
        root: Directory('${support.path}/sanskrit_yoga_audio_v1'),
        readBundled: (clip) async {
          final data = await rootBundle.load(
            'assets/practice/sanskrit_yoga_audio/${clip.id}.mp3',
          );
          return data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        },
      );
    });

final yogaAudioServiceProvider = Provider.autoDispose<SanskritAudioService>((
  ref,
) {
  final service = SanskritAudioService(
    repository: ref.watch(yogaAudioRepositoryProvider.future),
  );
  ref.onDispose(service.dispose);
  return service;
});
