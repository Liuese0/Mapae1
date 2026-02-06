import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter get router => _router;

  static final _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
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
