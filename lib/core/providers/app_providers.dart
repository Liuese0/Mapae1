import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/ocr_service.dart';
import '../services/premium_service.dart';

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

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
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

// ──────────────── Premium (광고 제거) ────────────────

final premiumServiceProvider = Provider<PremiumService>((ref) {
  final service = PremiumService();
  ref.onDispose(service.dispose);
  return service;
});

/// 프리미엄(광고 제거) 상태 관리.
///
/// `true` → 광고 숨김 / `false` → 광고 표시
final isPremiumProvider =
StateNotifierProvider<PremiumNotifier, bool>((ref) {
  final service = ref.watch(premiumServiceProvider);
  return PremiumNotifier(service);
});

class PremiumNotifier extends StateNotifier<bool> {
  final PremiumService _service;

  PremiumNotifier(this._service) : super(false) {
    _init();
  }

  Future<void> _init() async {
    state = await _service.isPremium();
    // 구매 완료/복원 이벤트 수신 시작
    _service.startListening(() => state = true);
  }

  /// 광고 제거 구매를 시작합니다.
  /// 성공 시 null, 실패 시 한국어 오류 메시지 반환.
  Future<String?> purchase() => _service.purchaseRemoveAds();

  /// 이전 구매 내역 복원.
  Future<void> restore() => _service.restorePurchases();
}

// ──────────────── Theme Mode ────────────────

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.light;
});

// ──────────────── Locale ────────────────

final localeProvider = StateProvider<Locale>((ref) {
  return const Locale('ko');
});

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