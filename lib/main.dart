import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/ad_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_providers.dart';
import 'core/utils/router.dart';
import 'core/services/auto_login_service.dart';
import 'l10n/generated/app_localizations.dart';

// re-export helpers used in main()
export 'core/providers/app_providers.dart' show loadSavedLocale, LocaleNotifier;

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

  // 저장된 언어 로드 + 첫 실행 여부 확인
  final savedLocale = await loadSavedLocale();
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

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: AppRouter.router,
    );
  }
}