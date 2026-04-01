import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/ocr_service.dart';
import '../services/gemini_ocr_service.dart';
import '../services/smart_ocr_service.dart';
import '../services/azure_ocr_service.dart';
import '../services/premium_service.dart';
import '../services/caller_id_service.dart';

import '../services/auto_login_service.dart';
import '../services/image_processing_service.dart';
import '../services/document_scanner_service.dart';
import '../../features/shared/models/app_user.dart';
import '../../features/shared/models/category.dart';
import '../../features/shared/models/team_invitation.dart';

// ──────────────── Services ────────────────

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final ocrServiceProvider = Provider<SmartOcrService>((ref) {
  return SmartOcrService(
    GeminiOcrService(),
    OcrService(),
    AzureOcrService(),
  );
});


final callerIdServiceProvider = Provider<CallerIdService>((ref) {
  return CallerIdService();
});

final autoLoginServiceProvider = Provider<AutoLoginService>((ref) {
  return AutoLoginService();
});

final imageProcessingServiceProvider = Provider<ImageProcessingService>((ref) {
  return ImageProcessingService();
});

final documentScannerServiceProvider = Provider<DocumentScannerService>((ref) {
  return DocumentScannerService();
});

// ──────────────── Auth State ────────────────

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.read(supabaseServiceProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  // auth 상태 변화를 감시하여 로그인/로그아웃에 반응
  ref.watch(authStateProvider);
  return ref.read(supabaseServiceProvider).currentUser;
});

// ──────────────── User Profile ────────────────

final userProfileProvider =
StateNotifierProvider<UserProfileNotifier, AsyncValue<AppUser?>>((ref) {
  return UserProfileNotifier(ref);
});

class UserProfileNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final Ref _ref;

  UserProfileNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadProfile();
    // auth 상태 변화 감시 → 로그아웃 시 프로필 리셋
    _ref.listen(authStateProvider, (previous, next) {
      next.whenData((authState) {
        if (authState.event == AuthChangeEvent.signedOut) {
          state = const AsyncValue.data(null);
        } else if (authState.event == AuthChangeEvent.signedIn) {
          _loadProfile();
        }
      });
    });
  }

  Future<void> _loadProfile() async {
    final service = _ref.read(supabaseServiceProvider);
    final user = service.currentUser;
    if (user == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      // 프로필이 없으면 자동 생성 (회원가입 후 첫 로그인, Google 로그인 등)
      final profile = await service.ensureUserProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadProfile();
  }

  Future<void> updateLocale(String locale) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(locale: locale);
    await _ref.read(supabaseServiceProvider).updateUserProfile(updated);
    state = AsyncValue.data(updated);
  }

  Future<void> updateDarkMode(bool isDarkMode) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(isDarkMode: isDarkMode);
    await _ref.read(supabaseServiceProvider).updateUserProfile(updated);
    state = AsyncValue.data(updated);
  }
}

// ──────────────── Premium / Pro 구독 ────────────────

final premiumServiceProvider = Provider<PremiumService>((ref) {
  final service = PremiumService();
  ref.onDispose(service.dispose);
  return service;
});

/// 프리미엄 + Pro 전체 상태 관리.
final premiumStateProvider =
StateNotifierProvider<PremiumNotifier, PremiumState>((ref) {
  final service = ref.watch(premiumServiceProvider);
  return PremiumNotifier(service);
});

/// 광고 제거 여부 (Pro 또는 레거시 구매자 모두 true).
/// 기존 코드 하위 호환용 derived provider.
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(premiumStateProvider).hasAdsRemoved;
});

/// Pro 구독 활성 여부.
final isProProvider = Provider<bool>((ref) {
  return ref.watch(premiumStateProvider).isPro;
});

/// 레거시 광고제거 구매 여부.
final isLegacyPremiumProvider = Provider<bool>((ref) {
  return ref.watch(premiumStateProvider).isPremiumLegacy;
});

class PremiumNotifier extends StateNotifier<PremiumState> {
  final PremiumService _service;

  PremiumNotifier(this._service) : super(PremiumState.initial) {
    _init();
  }

  Future<void> _init() async {
    state = await _service.loadPremiumState();
    _service.startListening(() async {
      state = await _service.loadPremiumState();
    });
  }

  /// 레거시 광고 제거 구매 (₩1,000 일회성).
  Future<String?> purchaseLegacy() => _service.purchaseRemoveAds();

  /// Pro 월간 구독 구매 (₩3,900/월).
  Future<String?> purchaseProMonthly() => _service.purchaseProMonthly();

  /// Pro 연간 구독 구매 (₩39,000/년).
  Future<String?> purchaseProAnnual() => _service.purchaseProAnnual();

  /// Pro 레거시 할인 구독 구매 (₩3,400/월, 기존 광고제거 구매자 전용).
  Future<String?> purchaseProLegacyDiscount() =>
      _service.purchaseProLegacyDiscount();

  /// 이전 구매 내역 복원.
  Future<void> restore() => _service.restorePurchases();

  // 하위 호환: 기존 코드에서 purchase()를 사용하는 경우
  Future<String?> purchase() => _service.purchaseRemoveAds();
}

// ──────────────── Theme Mode ────────────────

const _kThemeModeKey = 'app_theme_mode';

/// 앱 시작 시 저장된 테마 모드를 로드합니다.
Future<ThemeMode> loadSavedThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_kThemeModeKey);
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.light;
  }
}

final themeModeProvider =
StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light);

  void init(ThemeMode mode) {
    state = mode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
  }
}

// ──────────────── Locale ────────────────

const _kLocaleKey = 'app_locale';
const _kLanguageSelectedKey = 'language_selected';

/// 앱 시작 시 저장된 언어를 SharedPreferences에서 읽어 옵니다.
/// main()에서 호출하여 ProviderScope override로 주입합니다.
Future<Locale> loadSavedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_kLocaleKey);
  if (code != null && ['ko', 'en'].contains(code)) {
    return Locale(code);
  }
  return const Locale('ko');
}

/// 언어 선택 완료 여부를 반환합니다.
Future<bool> isLanguageSelected() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kLanguageSelectedKey) ?? false;
}

final localeProvider =
StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ko'));

  /// 초기 언어를 외부에서 주입 (main에서 호출)
  void init(Locale locale) {
    state = locale;
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
    await prefs.setBool(_kLanguageSelectedKey, true);
  }
}

// ──────────────── Categories ────────────────

final categoriesProvider =
FutureProvider.autoDispose<List<CardCategory>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  final user = service.currentUser;
  if (user == null) return [];
  return service.getCategories(user.id);
});

final teamCategoriesProvider =
FutureProvider.autoDispose.family<List<CardCategory>, String>(
        (ref, teamId) async {
      final service = ref.read(supabaseServiceProvider);
      return service.getTeamCategories(teamId);
    });

// ──────────────── Invitations ────────────────

final pendingInvitationsProvider =
FutureProvider.autoDispose<List<TeamInvitation>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getReceivedInvitations();
});

final pendingInvitationCountProvider =
FutureProvider.autoDispose<int>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getPendingInvitationCount();
});