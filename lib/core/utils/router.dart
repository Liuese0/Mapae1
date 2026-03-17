import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/language_select_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/management/screens/management_screen.dart';
import '../../features/card_detail/screens/card_detail_screen.dart';
import '../../features/card_detail/screens/card_edit_screen.dart';
import '../../features/management/screens/my_card_edit_screen.dart';
import '../../features/management/screens/team_management_screen.dart';
import '../../features/management/screens/tag_template_screen.dart';
import '../../features/management/screens/profile_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/card_detail/screens/shared_card_receive_screen.dart';
import '../../features/shared/widgets/main_shell.dart';
import '../services/auto_login_service.dart';

/// Wraps GoRouter's [RouteInformationParser] to gracefully handle
/// custom-scheme deep links (e.g. `com.namecard.app://login-callback`).
///
/// GoRouter v13 calls `Uri.origin` during parsing, which throws a [StateError]
/// for non-http/https schemes. This wrapper intercepts such URIs and replaces
/// them with a safe fallback path before they reach the inner parser.
class SafeRouteInformationParser
    extends RouteInformationParser<RouteMatchList> {
  SafeRouteInformationParser(this._router);
  final GoRouter _router;

  RouteInformationParser<RouteMatchList> get _delegate =>
      _router.routeInformationParser;

  @override
  Future<RouteMatchList> parseRouteInformationWithDependencies(
      RouteInformation routeInformation,
      BuildContext context,
      ) {
    final uri = routeInformation.uri;
    if (uri.scheme.isNotEmpty &&
        uri.scheme != 'http' &&
        uri.scheme != 'https') {
      // Custom-scheme URI — replace with a safe path so GoRouter won't crash.
      final session = Supabase.instance.client.auth.currentSession;
      final fallback = session != null ? '/home' : '/login';
      return _delegate.parseRouteInformationWithDependencies(
        RouteInformation(
          uri: Uri.parse(fallback),
          state: routeInformation.state,
        ),
        context,
      );
    }
    return _delegate.parseRouteInformationWithDependencies(
        routeInformation, context);
  }

  @override
  Future<RouteMatchList> parseRouteInformation(
      RouteInformation routeInformation) {
    return _delegate.parseRouteInformation(routeInformation);
  }

  @override
  RouteInformation? restoreRouteInformation(RouteMatchList configuration) {
    return _delegate.restoreRouteInformation(configuration);
  }
}


class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter get router => _router;

  /// 앱 첫 실행 여부 (언어 선택 완료 전)를 캐싱합니다.
  static bool? _languageSelected;

  static Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();
    _languageSelected = prefs.getBool('language_selected') ?? false;
  }

  static String get _initialLocation {
    if (_languageSelected == false) return '/language-select';
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? '/home' : '/login';
  }

  static final _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: _initialLocation,
    onException: (context, state, router) {
      // When the OS delivers a deep link (e.g. com.namecard.app://share/TOKEN),
      // Flutter's platform routing passes the raw URI to GoRouter before
      // app_links can intercept it. GoRouter cannot match the custom-scheme URI
      // against path-based routes, so it calls onException instead of crashing.
      final uri = state.uri;
      if (uri.host == 'share' && uri.pathSegments.isNotEmpty) {
        router.go('/shared-card/${uri.pathSegments.first}');
      } else if (uri.host == 'login-callback') {
        // OAuth callback (Kakao, etc.) — Supabase handles the auth exchange
        // via its own deep link listener. Just navigate to the appropriate page.
        final session = Supabase.instance.client.auth.currentSession;
        router.go(session != null ? '/home' : '/login');
      } else {
        router.go(_initialLocation);
      }
    },
    routes: [
      // Language selection (first run only)
      GoRoute(
        path: '/language-select',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LanguageSelectScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),

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
        path: '/profile',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
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
        path: '/shared-card/:token',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: SharedCardReceiveScreen(
            token: state.pathParameters['token']!,
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