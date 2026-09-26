import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/welcome_page.dart';
import '../features/learning_path/learning_path_page.dart';
import '../features/lesson/lesson_page.dart';
import '../features/lesson/result_page.dart';
import '../features/rewards/rewards_page.dart';
import 'providers.dart';

const _authLocations = ['/welcome', '/login', '/register'];

/// 路由：感知认证状态，无会话时重定向到欢迎页
final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final onAuth = _authLocations.contains(state.matchedLocation);
      if (!auth.hasSession && !onAuth) return '/welcome';
      if (auth.hasSession && onAuth) {
        // 游客允许进入登录/注册页升级账号
        if (auth.isGuest && state.matchedLocation != '/welcome') return null;
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LearningPathPage()),
      GoRoute(
        path: '/rewards',
        builder: (context, state) => const RewardsPage(),
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
});
