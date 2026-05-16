import 'dart:async';
import 'dart:io' show Platform;
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/ad_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_providers.dart';
import 'core/utils/root_messenger.dart';
import 'core/utils/router.dart';
import 'core/services/auto_login_service.dart';
import 'features/caller_id/widgets/caller_id_overlay.dart';
import 'l10n/generated/app_localizations.dart';

// re-export helpers used in main()
export 'core/providers/app_providers.dart' show loadSavedLocale, LocaleNotifier, loadSavedThemeMode, ThemeModeNotifier, loadDefaultTemplateId, DefaultTemplateIdNotifier;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob
  await AdService.initialize();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // 자동 로그인이 꺼져 있으면 기존 세션을 제거
  final autoLoginService = AutoLoginService();
  final autoLoginEnabled = await autoLoginService.isEnabled();
  if (!autoLoginEnabled) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  // 저장된 언어 + 테마 모드 로드
  final savedLocale = await loadSavedLocale();
  final savedThemeMode = await loadSavedThemeMode();
  final savedTemplateId = await loadDefaultTemplateId();
  await AppRouter.preload();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => LocaleNotifier()..init(savedLocale)),
        themeModeProvider.overrideWith((ref) => ThemeModeNotifier()..init(savedThemeMode)),
        defaultTemplateIdProvider.overrideWith((ref) => DefaultTemplateIdNotifier()..init(savedTemplateId)),
      ],
      child: const NameCardApp(),
    ),
  );
}

class NameCardApp extends ConsumerStatefulWidget {
  const NameCardApp({super.key});

  @override
  ConsumerState<NameCardApp> createState() => _NameCardAppState();
}

class _NameCardAppState extends ConsumerState<NameCardApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
    _initCallerIdIfNeeded();
  }

  Future<void> _initCallerIdIfNeeded() async {
    // Caller ID는 Android 전용 (phone_state + flutter_overlay_window)
    if (!Platform.isAndroid) return;

    final callerService = ref.read(callerIdServiceProvider);
    final enabled = await callerService.isEnabled;
    if (!enabled) return;

    // 사용자가 '설정' 앱에서 권한을 회수했을 수 있다.
    // 권한이 없으면 phone_state 스트림이 이벤트를 발생시키지 않으므로
    // 조용히 종료하고 토글 상태도 false 로 동기화한다.
    final hasPerms = await callerService.hasRequiredPermissions();
    if (!hasPerms) {
      await callerService.setEnabled(false);
      return;
    }

    final supabaseService = ref.read(supabaseServiceProvider);
    final user = supabaseService.currentUser;
    if (user == null) return;

    final cards = await supabaseService.getCollectedCards(user.id, limit: 10000);
    await callerService.buildIndex(collectedCards: cards);
    await callerService.startListening();
  }

  Future<void> _initDeepLinks() async {
    // Handle link when app is opened from a deep link (cold start)
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) _handleDeepLink(initialLink);
    } catch (_) {}

    // Handle links when app is already running (warm start)
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    // OAuth callbacks (login-callback) are handled by Supabase's own
    // deep link listener — skip them here to avoid conflicts.
    if (uri.host == 'login-callback') return;

    // com.namecard.app://share/TOKEN
    if (uri.host == 'share' && uri.pathSegments.isNotEmpty) {
      final token = uri.pathSegments.first;
      AppRouter.router.go('/shared-card/$token');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    final goRouter = AppRouter.router;
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routeInformationProvider: goRouter.routeInformationProvider,
      routeInformationParser: SafeRouteInformationParser(goRouter),
      routerDelegate: goRouter.routerDelegate,
      backButtonDispatcher: goRouter.backButtonDispatcher,
    );
  }
}

/// flutter_overlay_window 오버레이 엔트리포인트
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CallerIdOverlay(),
  ));
}