import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/app/router.dart';
import 'package:english_village/app/selected_track_controller.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/features/sanskrit_audio/sanskrit_audio_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth(bool signedIn)
    : super(signedIn ? const AuthState(userKey: 'test') : const AuthState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Track extends StateNotifier<CourseTrack>
    implements SelectedTrackController {
  _Track(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('bundled audio catalog is registered in Flutter assets', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final catalog = await container.read(sanskritSoundCatalogProvider.future);
    expect(catalog.sounds.length, 48);
    expect(catalog.sounds.first.iast, 'a');
  });

  for (final (track, signedIn, expected) in [
    (CourseTrack.sanskritZero, true, '/sanskrit-audio'),
    (CourseTrack.sanskrit, true, '/sanskrit-audio'),
    (CourseTrack.zero, true, '/'),
    (CourseTrack.chineseZero, true, '/'),
    (CourseTrack.sanskritZero, false, '/welcome'),
  ]) {
    testWidgets('audio route respects session and language: $track $signedIn', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _Auth(signedIn)),
          selectedTrackProvider.overrideWith((ref) => _Track(track)),
        ],
      );
      addTearDown(container.dispose);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final router = container.read(goRouterProvider);
      router.go('/sanskrit-audio');
      final match = await router.routeInformationParser
          .parseRouteInformationWithDependencies(
            router.routeInformationProvider.value,
            context,
          );
      expect(match.uri.path, expected);
    });
  }
}
