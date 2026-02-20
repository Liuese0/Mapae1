import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  // ──────────────────────────────────────────────────────────────────────────
  // Ad Unit IDs
  // ──────────────────────────────────────────────────────────────────────────

  /// 네이티브 광고 단위 ID.
  ///
  /// ⚠️ TODO: 프로덕션 배포 전에 AdMob 콘솔에서 생성한 실제 네이티브 광고 단위 ID로
  /// 교체하세요.
  /// AdMob 콘솔 → 앱 → [앱 선택] → 광고 단위 → 네이티브 고급 → 광고 단위 만들기
  ///
  /// 현재 값: Google 공식 테스트 ID (실제 수익 없음)
  static const String nativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110'; // Test ID

  // ──────────────────────────────────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }
}
