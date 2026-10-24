import 'dart:async';
import 'dart:io';

import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/core/services/backup_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/models/user.dart';
import 'package:english_village/data/repositories/user_repository.dart';
import 'package:english_village/data/sources/cloud_auth_api.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/data/sources/reward_store.dart';
import 'package:english_village/data/sources/settings_store.dart';
import 'package:english_village/data/sources/sync_api.dart';
import 'package:english_village/data/sources/token_store.dart';
import 'package:english_village/data/sources/user_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class ReviewCloud extends CloudAuthApi {
  final refreshStarted = Completer<void>();
  final refreshResult = Completer<String>();
  @override
  Future<OnlineAuthResult> register({
    String? email,
    String? phone,
    required String password,
    String? displayName,
  }) async => const OnlineAuthResult(
    account: OnlineAccount(accountId: 'review-account', displayName: 'Review'),
    accessToken: 'review-access',
    refreshToken: 'review-refresh',
  );
  @override
  Future<String> refreshAccessToken(String token) {
    if (!refreshStarted.isCompleted) refreshStarted.complete();
    return refreshResult.future;
  }

  @override
  Future<void> logout(String token) async {}
}

class ReviewSync extends SyncApi {
  Map<String, dynamic>? uploaded;
  @override
  Future<RemoteSnapshot?> pull(String token) async => null;
  @override
  Future<void> push(
    String token,
    Map<String, dynamic> payload,
    int updatedAt, {
    int? baseClientUpdatedAt,
    Map<String, dynamic>? device,
  }) async {
    uploaded = payload;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  setUpAll(() {
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(LessonProgressAdapter());
  });
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('global_village_review_');
    Hive.init(temporary.path);
    await Hive.openBox<User>(UserStore.usersBoxName);
    await Hive.openBox<String>(UserStore.sessionBoxName);
    await Hive.openBox<LessonProgress>(ProgressStore.boxName);
    await Hive.openBox<String>(RewardStore.boxName);
    await Hive.openBox<String>(SettingsStore.boxName);
  });
  tearDown(() async {
    await Hive.close();
    await temporary.delete(recursive: true);
  });

  test(
    'binding must copy local progress through production providers',
    () async {
      final users = UserStore();
      await users.putUser(
        User(
          nickname: 'review-local',
          passwordHash: 'hash',
          salt: 'salt',
          createdAt: DateTime(2026),
        ),
      );
      await users.setSession('review-local');
      await const ProgressStore(userKey: 'review-local').save(
        const LessonProgress(
          lessonId: 'u1l1',
          completed: true,
          score: 100,
          correctCount: 9,
          totalCount: 9,
        ),
      );
      await const RewardStore(
        userKey: 'review-local',
      ).save('review-attempt', 'u1l1');
      final api = ReviewSync();
      final container = ProviderContainer(
        overrides: [
          cloudAuthApiProvider.overrideWithValue(ReviewCloud()),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          syncApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      final error = await container
          .read(authProvider.notifier)
          .registerAndBind(
            email: 'review@example.invalid',
            password: 'review-password',
          );
      expect(error, isNull);
      await container.read(syncServiceProvider)!.pullMergePush();
      expect(container.read(authProvider).userKey, 'online:review-account');
      expect(
        const ProgressStore(userKey: 'online:review-account').get('u1l1'),
        isNotNull,
      );
    },
  );

  for (final lessonId in ['zh_u1l1', 'zh_u2l1', 'sa_u1l1', 'sa_u3l1']) {
    test('exported backup must import a reward for $lessonId', () async {
      final users = UserStore();
      await users.putUser(
        User(
          nickname: 'review-local',
          passwordHash: 'hash',
          salt: 'salt',
          createdAt: DateTime(2026),
        ),
      );
      await users.setSession('review-local');
      await const RewardStore(
        userKey: 'review-local',
      ).save('review-attempt', lessonId);
      final backups = BackupService(userStore: users);
      final code = (await backups.exportBackup())!;
      expect(await backups.importBackup(code), isNull);
    });
  }

  test(
    'refresh completing after logout must not restore the session',
    () async {
      final users = UserStore();
      await users.setSession('online:review-account');
      final tokens = MemoryTokenStore()..token = 'review-refresh';
      final cloud = ReviewCloud();
      final auth = AuthController(
        UserRepository(store: users),
        cloudAuth: cloud,
        tokenStore: tokens,
      );
      addTearDown(auth.dispose);
      await cloud.refreshStarted.future;
      await auth.logout();
      expect(auth.state.hasSession, isFalse);
      cloud.refreshResult.complete('review-access');
      await Future<void>.delayed(Duration.zero);
      expect(auth.state.hasSession, isFalse);
    },
  );

  test('numeric pinyin must put the tone on the syllable main vowel', () {
    const exercise = Exercise(
      id: 'review-pinyin',
      type: ExerciseType.translateInput,
      prompt: '',
      sentence: 'nǐ hǎo',
      options: [],
      answer: 'nǐ hǎo',
      language: LearningLanguage.chinese,
    );
    expect(exercise.accepts('ni3 hao3'), isTrue);
    expect(exercise.accepts('ni3 hao4'), isFalse);
  });

  for (final entry in {
    'gui3': 'guǐ',
    'liu2': 'liú',
    'shui3': 'shuǐ',
    'dou4': 'dòu',
    'jiang3': 'jiǎng',
    'lü4': 'lǜ',
    'nv3': 'nǚ',
  }.entries) {
    test('numeric pinyin ${entry.key} accepts ${entry.value}', () {
      final exercise = Exercise(
        id: 'pinyin',
        type: ExerciseType.translateInput,
        prompt: '',
        sentence: entry.value,
        options: [],
        answer: entry.value,
        language: LearningLanguage.chinese,
      );
      expect(exercise.accepts(entry.key), isTrue);
    });
  }
}
