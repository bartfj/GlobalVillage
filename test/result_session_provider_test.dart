import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/data/models/course.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth()
    : super(const AuthState(userKey: 'online:alice', accessToken: 'first'));
  void change(String userKey, String token) =>
      state = AuthState(userKey: userKey, accessToken: token);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('same-account token refresh retains the active result repositories', () {
    final auth = _Auth();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => auth),
        courseProvider.overrideWithValue(
          const Course(id: 'beginner', title: '', units: []),
        ),
      ],
    );
    addTearDown(container.dispose);
    final progress = container.read(progressRepositoryProvider);
    final rewards = container.read(rewardRepositoryProvider);
    auth.change('online:alice', 'refreshed');
    expect(
      identical(container.read(progressRepositoryProvider), progress),
      isTrue,
    );
    expect(
      identical(container.read(rewardRepositoryProvider), rewards),
      isTrue,
    );
  });
  test(
    'account replacement produces separately scoped result repositories',
    () {
      final auth = _Auth();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => auth),
          courseProvider.overrideWithValue(
            const Course(id: 'beginner', title: '', units: []),
          ),
        ],
      );
      addTearDown(container.dispose);
      final progress = container.read(progressRepositoryProvider);
      final rewards = container.read(rewardRepositoryProvider);
      auth.change('online:bob', 'other-account');
      expect(
        identical(container.read(progressRepositoryProvider), progress),
        isFalse,
      );
      expect(
        identical(container.read(rewardRepositoryProvider), rewards),
        isFalse,
      );
      expect(
        container.read(progressRepositoryProvider)!.store.userKey,
        'online:bob',
      );
      expect(
        container.read(rewardRepositoryProvider)!.store.userKey,
        'online:bob',
      );
    },
  );
}
