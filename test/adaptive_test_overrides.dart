import 'package:english_village/app/app_strings.dart';
import 'package:english_village/app/auth_controller.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/app/selected_track_controller.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/models/learning_language.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/repositories/reward_repository.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:english_village/data/sources/settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdaptiveTestAuth extends StateNotifier<AuthState>
    implements AuthController {
  AdaptiveTestAuth() : super(const AuthState(userKey: 'test'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AdaptiveTestTrack extends StateNotifier<CourseTrack>
    implements SelectedTrackController {
  AdaptiveTestTrack(super.state);
  @override
  Future<void> select(CourseTrack track) async => state = track;
  @override
  CourseTrack rememberedTrack(LearningLanguage language) =>
      CourseTrack.values.firstWhere((track) => track.language == language);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings implements SettingsStore {
  @override
  String? get uiLanguageOverride => null;
  @override
  String get apiBaseUrl => 'https://example.com/v1';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Progress implements ProgressStore {
  @override
  LessonProgress? get(String id) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rewards implements RewardRepository {
  @override
  int get treeCount => 0;
  @override
  int unlockedBadgeCount(Iterable<Course> courses) => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Course _course(CourseTrack track) => Course(
  id: track.id,
  title: track.id,
  units: const [
    Unit(
      id: 'u1',
      title: 'Unit 1',
      description: '',
      lessons: [Lesson(id: 'u1l1', title: 'Hello', exercises: [])],
    ),
  ],
);

List<Override> adaptiveTestOverrides({
  CourseTrack track = CourseTrack.beginner,
  SelectedTrackController? controller,
  UiLanguage language = UiLanguage.chinese,
  Course? previewCourse,
}) => [
  stringsProvider.overrideWithValue(S(language)),
  authProvider.overrideWith((ref) => AdaptiveTestAuth()),
  settingsStoreProvider.overrideWithValue(_Settings()),
  selectedTrackProvider.overrideWith(
    (ref) => controller ?? AdaptiveTestTrack(track),
  ),
  courseProvider.overrideWith((ref) {
    final selected = ref.watch(selectedTrackProvider);
    return previewCourse?.id == selected.id
        ? previewCourse!
        : _course(selected);
  }),
  allCoursesProvider.overrideWith(
    (ref) async => CourseTrack.values.map(_course).toList(),
  ),
  progressRepositoryProvider.overrideWith(
    (ref) => ProgressRepository(
      store: _Progress(),
      course: ref.watch(courseProvider),
    ),
  ),
  rewardRepositoryProvider.overrideWithValue(_Rewards()),
];
