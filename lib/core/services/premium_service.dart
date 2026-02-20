import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 프리미엄(광고 제거) 구매 및 상태 관리 서비스.
///
/// ⚠️ TODO: 프로덕션 배포 전에 Google Play Console에서 인앱 상품을 생성하세요.
///   - 상품 ID: [productId] 상수값과 동일하게 설정
///   - 상품 유형: 일회성 구매(Non-consumable)
///   - 가격: ₩1,000
class PremiumService {
  // ──────────────────────────────────────────────────────────────────────────
  // Constants
  // ──────────────────────────────────────────────────────────────────────────

  /// SharedPreferences 키.
  static const String _premiumKey = 'mapae_is_premium';

  /// Google Play Console에 등록할 인앱 상품 ID.
  ///
  /// ⚠️ TODO: Play Console → 앱 → 수익 창출 → 제품 → 인앱 상품에서
  /// 아래 ID와 동일하게 등록하세요.
  static const String productId = 'remove_ads';

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
  /// 앱 시작 시 한 번 호출하며, 결제 완료·복원 시 [onPremiumActivated]를 호출합니다.
  void startListening(VoidCallback onPremiumActivated) {
    _purchaseSubscription = _iap.purchaseStream.listen(
          (purchaseList) =>
          _handlePurchaseUpdates(purchaseList, onPremiumActivated),
      onError: (Object error) {
        debugPrint('[PremiumService] purchaseStream error: $error');
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // State Queries
  // ──────────────────────────────────────────────────────────────────────────

  Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumKey) ?? false;
  }

  Future<void> setPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Purchase
  // ──────────────────────────────────────────────────────────────────────────

  /// 광고 제거 상품 구매를 시작합니다.
  ///
  /// 성공적으로 구매 흐름이 시작되면 [null] 반환.
  /// 오류 발생 시 한국어 오류 메시지 반환.
  Future<String?> purchaseRemoveAds() async {
    final available = await _iap.isAvailable();
    if (!available) {
      return '구글 플레이 결제를 사용할 수 없습니다.\n스토어 로그인 상태를 확인해주세요.';
    }

    final response = await _iap.queryProductDetails({productId});
    if (response.error != null) {
      debugPrint('[PremiumService] queryProductDetails error: ${response.error}');
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
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return null; // 구매 흐름이 성공적으로 시작됨
    } catch (e) {
      debugPrint('[PremiumService] buyNonConsumable error: $e');
      return '구매를 시작할 수 없습니다. 다시 시도해주세요.';
    }
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
  // Internal
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _handlePurchaseUpdates(
      List<PurchaseDetails> purchaseList,
      VoidCallback onPremiumActivated,
      ) async {
    for (final purchase in purchaseList) {
      if (purchase.productID != productId) continue;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await setPremium(true);
          onPremiumActivated();
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        case PurchaseStatus.error:
          debugPrint(
              '[PremiumService] Purchase error: ${purchase.error?.message}');
        case PurchaseStatus.canceled:
          debugPrint('[PremiumService] Purchase canceled');
        case PurchaseStatus.pending:
          debugPrint('[PremiumService] Purchase pending');
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