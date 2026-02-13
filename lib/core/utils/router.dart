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
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/shared/widgets/main_shell.dart';
import '../services/auto_login_service.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter get router => _router;

  static String get _initialLocation {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return '/home';
    }
    return '/login';
  }

  static final _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: _initialLocation,
    routes: [
      // Auth routes with fade transition
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SignUpScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
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

      // Detail routes with slide-up transition
      GoRoute(
        path: '/card/:id',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: CardDetailScreen(
            cardId: state.pathParameters['id']!,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween(
              begin: const Offset(0.0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(
        path: '/card/:id/edit',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: CardEditScreen(
            cardId: state.pathParameters['id']!,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return SlideTransition(position: slide, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(
        path: '/my-card/edit',
        pageBuilder: (context, state) {
          final cardId = state.uri.queryParameters['id'];
          return CustomTransitionPage(
            key: state.pageKey,
            child: MyCardEditScreen(cardId: cardId),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final slide = Tween(
                begin: const Offset(0.0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slide,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
      GoRoute(
        path: '/team/:id',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: TeamManagementScreen(
            teamId: state.pathParameters['id']!,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return SlideTransition(position: slide, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(
        path: '/tag-templates',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const TagTemplateScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return SlideTransition(position: slide, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NotificationsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween(
              begin: const Offset(0.0, -0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
    ],
  );
}