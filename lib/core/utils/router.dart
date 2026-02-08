import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/management/screens/management_screen.dart';
import '../../features/card_detail/screens/card_detail_screen.dart';
import '../../features/card_detail/screens/card_edit_screen.dart';
import '../../features/management/screens/my_card_edit_screen.dart';
import '../../features/management/screens/team_management_screen.dart';
import '../../features/management/screens/tag_template_screen.dart';
import '../../features/shared/widgets/main_shell.dart';
import '../services/auto_login_service.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter get router => _router;

  /// 자동 로그인 여부에 따라 초기 경로를 결정
  static String get _initialLocation {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // 세션이 존재하면 자동 로그인 설정과 관계없이 홈으로
      // (세션은 자동 로그인이 켜져 있을 때만 유지됨)
      return '/home';
    }
    return '/login';
  }

  static final _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: _initialLocation,
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),

      // Main app shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/wallet',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WalletScreen(),
            ),
          ),
          GoRoute(
            path: '/management',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ManagementScreen(),
            ),
          ),
        ],
      ),

      // Detail routes (outside shell for full screen)
      GoRoute(
        path: '/card/:id',
        builder: (context, state) => CardDetailScreen(
          cardId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/card/:id/edit',
        builder: (context, state) => CardEditScreen(
          cardId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/my-card/edit',
        builder: (context, state) {
          final cardId = state.uri.queryParameters['id'];
          return MyCardEditScreen(cardId: cardId);
        },
      ),
      GoRoute(
        path: '/team/:id',
        builder: (context, state) => TeamManagementScreen(
          teamId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/tag-templates',
        builder: (context, state) => const TagTemplateScreen(),
      ),
    ],
  );
}