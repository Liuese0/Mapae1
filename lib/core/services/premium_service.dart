import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────────────────────────────────
// PremiumState — 프리미엄/Pro 상태 모델
// ──────────────────────────────────────────────────────────────────────────

/// 프리미엄 및 Pro 구독 상태를 나타내는 불변 모델.
class PremiumState {
  /// ₩1,000 일회성 광고제거 구매 여부 (레거시).
  final bool isPremiumLegacy;

  /// Pro 구독 활성 여부.
  final bool isPro;

  /// 활성 구독의 상품 ID (예: pro_monthly, pro_annual, pro_legacy_discount).
  final String? proProductId;

  const PremiumState({
    this.isPremiumLegacy = false,
    this.isPro = false,
    this.proProductId,
  });

  static const initial = PremiumState();

  /// 광고를 제거해야 하는지 여부. Pro 또는 레거시 구매자 모두 해당.
  bool get hasAdsRemoved => isPro || isPremiumLegacy;

  /// 무제한 명함 사용 가능 여부 (Pro만).
  bool get hasUnlimitedCards => isPro;

  /// 무제한 팀 사용 가능 여부 (Pro만).
  bool get hasUnlimitedTeams => isPro;

  PremiumState copyWith({
    bool? isPremiumLegacy,
    bool? isPro,
    String? proProductId,
  }) {
    return PremiumState(
      isPremiumLegacy: isPremiumLegacy ?? this.isPremiumLegacy,
      isPro: isPro ?? this.isPro,
      proProductId: proProductId ?? this.proProductId,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// PremiumService
// ──────────────────────────────────────────────────────────────────────────

/// 프리미엄(광고 제거) 및 Pro 구독 구매/상태 관리 서비스.
///
/// ⚠️ TODO: 프로덕션 배포 전에 Google Play Console에서 인앱 상품을 생성하세요.
///   - remove_ads: 일회성 구매(Non-consumable), ₩1,000
///   - pro_monthly: 구독, ₩3,900/월
///   - pro_annual: 구독, ₩39,000/년
///   - pro_legacy_discount: 구독, ₩3,400/월 (기존 광고제거 구매자 전용)
class PremiumService {
  // ──────────────────────────────────────────────────────────────────────────
  // Constants
  // ──────────────────────────────────────────────────────────────────────────

  // SharedPreferences 키
  static const String _premiumKey = 'mapae_is_premium';
  static const String _proKey = 'mapae_is_pro';
  static const String _proProductIdKey = 'mapae_pro_product';

  // 인앱 상품 ID
  static const String legacyProductId = 'remove_ads';
  static const String proMonthlyId = 'pro_monthly';
  static const String proAnnualId = 'pro_annual';
  static const String proLegacyDiscountId = 'pro_legacy_discount';

  /// 모든 Pro 구독 상품 ID.
  static const Set<String> proProductIds = {
    proMonthlyId,
    proAnnualId,
    proLegacyDiscountId,
  };

  /// 모든 인앱 상품 ID (레거시 + Pro).
  static const Set<String> allProductIds = {
    legacyProductId,
    ...proProductIds,
  };

  /// 무료 플랜 제한
  static const int freeMaxCards = 100;
  static const int freeMaxTeams = 1;

  // ──────────────────────────────────────────────────────────────────────────
  // Fields
  // ──────────────────────────────────────────────────────────────────────────

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // ──────────────────────────────────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────────────────────────────────

  /// 구매 스트림 구독 시작.
  ///
  /// 앱 시작 시 한 번 호출하며, 결제 완료·복원 시 [onStateChanged]를 호출합니다.
  void startListening(VoidCallback onStateChanged) {
    _purchaseSubscription = _iap.purchaseStream.listen(
          (purchaseList) =>
          _handlePurchaseUpdates(purchaseList, onStateChanged),
      onError: (Object error) {
        debugPrint('[PremiumService] purchaseStream error: $error');
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // State Queries
  // ──────────────────────────────────────────────────────────────────────────

  /// 저장된 프리미엄/Pro 상태를 로드합니다.
  Future<PremiumState> loadPremiumState() async {
    final prefs = await SharedPreferences.getInstance();
    return PremiumState(
      isPremiumLegacy: prefs.getBool(_premiumKey) ?? false,
      isPro: prefs.getBool(_proKey) ?? false,
      proProductId: prefs.getString(_proProductIdKey),
    );
  }

  /// 레거시 광고제거 상태를 저장합니다.
  Future<void> setPremiumLegacy(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
  }

  /// Pro 구독 상태를 저장합니다.
  Future<void> setProState(bool isPro, {String? productId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proKey, isPro);
    if (productId != null) {
      await prefs.setString(_proProductIdKey, productId);
    } else if (!isPro) {
      await prefs.remove(_proProductIdKey);
    }
  }

  // 하위 호환: 기존 코드에서 사용하는 메서드
  Future<bool> isPremium() async {
    final state = await loadPremiumState();
    return state.hasAdsRemoved;
  }

  Future<void> setPremium(bool value) async {
    await setPremiumLegacy(value);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Purchase — 레거시 광고제거
  // ──────────────────────────────────────────────────────────────────────────

  /// 광고 제거 상품 구매를 시작합니다 (₩1,000 일회성).
  Future<String?> purchaseRemoveAds() async {
    return _purchaseProduct(legacyProductId, isSubscription: false);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Purchase — Pro 구독
  // ──────────────────────────────────────────────────────────────────────────

  /// Pro 월간 구독 구매 (₩3,900/월).
  Future<String?> purchaseProMonthly() async {
    return _purchaseProduct(proMonthlyId, isSubscription: true);
  }

  /// Pro 연간 구독 구매 (₩39,000/년).
  Future<String?> purchaseProAnnual() async {
    return _purchaseProduct(proAnnualId, isSubscription: true);
  }

  /// Pro 레거시 할인 월간 구독 구매 (₩3,400/월, 기존 광고제거 구매자 전용).
  Future<String?> purchaseProLegacyDiscount() async {
    return _purchaseProduct(proLegacyDiscountId, isSubscription: true);
  }

  /// 이전 구매 내역을 복원합니다.
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[PremiumService] restorePurchases error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Internal — 공통 구매 로직
  // ──────────────────────────────────────────────────────────────────────────

  Future<String?> _purchaseProduct(
      String productId, {
        required bool isSubscription,
      }) async {
    final available = await _iap.isAvailable();
    if (!available) {
      return '구글 플레이 결제를 사용할 수 없습니다.\n스토어 로그인 상태를 확인해주세요.';
    }

    final response = await _iap.queryProductDetails({productId});
    if (response.error != null) {
      debugPrint(
          '[PremiumService] queryProductDetails error: ${response.error}');
      return '상품 정보를 불러올 수 없습니다.\n잠시 후 다시 시도해주세요.';
    }
    if (response.productDetails.isEmpty) {
      debugPrint('[PremiumService] Product not found: $productId');
      return '상품을 찾을 수 없습니다.\n앱을 최신 버전으로 업데이트해주세요.';
    }

    final purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );

    try {
      if (isSubscription) {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
      return null;
    } catch (e) {
      debugPrint('[PremiumService] purchase error ($productId): $e');
      return '구매를 시작할 수 없습니다. 다시 시도해주세요.';
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Internal — 구매 스트림 처리
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _handlePurchaseUpdates(
      List<PurchaseDetails> purchaseList,
      VoidCallback onStateChanged,
      ) async {
    for (final purchase in purchaseList) {
      final pid = purchase.productID;

      // 알려지지 않은 상품은 건너뜀
      if (!allProductIds.contains(pid)) continue;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (pid == legacyProductId) {
            await setPremiumLegacy(true);
          } else if (proProductIds.contains(pid)) {
            await setProState(true, productId: pid);
          }
          onStateChanged();
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        case PurchaseStatus.error:
          debugPrint(
              '[PremiumService] Purchase error ($pid): ${purchase.error?.message}');
        case PurchaseStatus.canceled:
          debugPrint('[PremiumService] Purchase canceled ($pid)');
        case PurchaseStatus.pending:
          debugPrint('[PremiumService] Purchase pending ($pid)');
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Dispose
  // ──────────────────────────────────────────────────────────────────────────

  void dispose() {
    _purchaseSubscription?.cancel();
  }
}