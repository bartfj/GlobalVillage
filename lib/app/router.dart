import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/diagnostic_log.dart';

import '../features/auth/account_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/welcome_page.dart';
import '../features/learning_path/completed_lessons_page.dart';
import '../features/learning_path/learning_path_page.dart';
import '../features/learning_path/review_page.dart';
import '../data/models/skill_practice.dart';
import '../data/models/learning_language.dart';
import '../features/sanskrit_audio/sanskrit_audio_page.dart';
import '../features/lesson/lesson_page.dart';
import '../features/lesson/result_page.dart';
import '../features/rewards/rewards_page.dart';
import '../features/rewards/tree_page.dart';
import '../features/skill_practice/skill_practice_page.dart';
import 'providers.dart';

const _authLocations = ['/welcome', '/login', '/register'];

/// 路由：感知认证状态，无会话时重定向到欢迎页。
/// 登录态变化只触发重定向，不重建路由器，避免当前页被 initialLocation 冲掉。
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    observers: [_DiagnosticRouteObserver()],
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final onAuth = _authLocations.contains(state.matchedLocation);
      if (!auth.hasSession && !onAuth) return '/welcome';
      if (state.matchedLocation == '/sanskrit-audio' &&
          ref.read(selectedTrackProvider).language != LearningLanguage.sanskrit) {
        return '/';
      }
      if (state.matchedLocation.startsWith('/practice/')) {
        // 专项练习按语言过滤：只能进入当前学习语言的专项
        final skill = SkillPracticeKind.tryParse(
          state.pathParameters['skill'] ?? '',
        );
        if (skill == null ||
            skill.language != ref.read(selectedTrackProvider).language) {
          return '/';
        }
      }
      if (auth.hasSession && onAuth) {
        // 游客允许进入登录/注册页升级账号
        if (auth.isGuest && state.matchedLocation != '/welcome') return null;
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LearningPathPage()),
      GoRoute(path: '/review', builder: (context, state) => const ReviewPage()),
      GoRoute(
        path: '/sanskrit-audio',
        builder: (context, state) => const SanskritAudioPage(),
      ),
      GoRoute(
        path: '/practice/:skill',
        builder: (context, state) {
          final skill = SkillPracticeKind.tryParse(
            state.pathParameters['skill'] ?? '',
          );
          if (skill == null) {
            return const LearningPathPage();
          }
          return SkillPracticePage(skill: skill);
        },
      ),
      GoRoute(
        path: '/badges',
        builder: (context, state) => const RewardsPage(),
      ),
      GoRoute(path: '/rewards', redirect: (context, state) => '/badges'),
      GoRoute(path: '/tree', builder: (context, state) => const TreePage()),
      GoRoute(
        path: '/completed',
        builder: (context, state) => const CompletedLessonsPage(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
        path: '/lesson/:lessonId',
        builder: (context, state) =>
            LessonPage(lessonId: state.pathParameters['lessonId']!),
      ),
      GoRoute(
        path: '/lesson/:lessonId/result',
        builder: (context, state) => ResultPage(
          lessonId: state.pathParameters['lessonId']!,
          result: state.extra! as LessonResult,
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _DiagnosticRouteObserver extends NavigatorObserver {
  void _remember(Route<dynamic>? route) {
    if (route == null) return;
    final log = DiagnosticLog.instance;
    if (log == null) return;
    final value = fillDiagnosticRoute(
      route.settings.name ?? '',
      route.settings.arguments,
    );
    if (value.isEmpty) return;
    log.setRoute(value);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remember(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _remember(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remember(previousRoute);
  }
}
