import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/ocr_service.dart';
import '../services/nfc_service.dart';
import '../services/auto_login_service.dart';
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

final nfcServiceProvider = Provider<NfcService>((ref) {
  return NfcService();
});

final autoLoginServiceProvider = Provider<AutoLoginService>((ref) {
  return AutoLoginService();
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