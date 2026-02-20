import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../core/services/ad_service.dart';

/// 명함 리스트에 삽입되는 네이티브 광고 카드.
///
/// - 앱의 명함 카드와 동일한 border radius / padding 적용
/// - 상단·하단 Divider로 명함과 구분
/// - 'Sponsored' 소형 회색 라벨로 광고임을 명확히 표시
/// - AdMob SDK 기본 클릭 동작 유지 (정책 준수)
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _adRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // context가 안정된 후 광고 로드 (테마 색상을 사용하기 위해)
    if (!_adRequested) {
      _adRequested = true;
      _loadAd();
    }
  }

  void _loadAd() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 앱 테마에 맞춘 네이티브 광고 스타일
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor =
    isDark ? Colors.white : const Color(0xFF1A1A1A);
    final secondaryTextColor =
    isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
    final ctaBg = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final ctaTextColor = isDark ? Colors.black : Colors.white;

    _nativeAd = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMob] Native ad failed: ${error.message}');
          ad.dispose();
          _nativeAd = null;
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        cornerRadius: 12.0,
        mainBackgroundColor: cardBg,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: ctaTextColor,
          backgroundColor: ctaBg,
          style: NativeTemplateFontStyle.bold,
          size: 12.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: primaryTextColor,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: secondaryTextColor,
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: secondaryTextColor,
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
    );
    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 광고가 로드되기 전에는 공간 차지 없이 숨김
    if (!_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outline.withOpacity(0.22);

    return Padding(
      // 명함 카드 좌우 패딩은 부모(ListView)에서 이미 적용됨
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 상단 구분선 ──
          Divider(color: dividerColor, height: 1, thickness: 1),
          const SizedBox(height: 8),

          // ── Sponsored 라벨 ──
          Text(
            'Sponsored',
            style: TextStyle(
              fontSize: 10,
              height: 1.2,
              color: theme.colorScheme.onSurface.withOpacity(0.30),
              fontWeight: FontWeight.w400,
              fontFamily: 'Pretendard',
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 5),

          // ── 네이티브 광고 (SDK 기본 클릭 동작 유지) ──
          SizedBox(
            height: 88,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.40),
                  ),
                ),
                child: AdWidget(ad: _nativeAd!),
              ),
            ),
          ),

          const SizedBox(height: 8),
          // ── 하단 구분선 ──
          Divider(color: dividerColor, height: 1, thickness: 1),
        ],
      ),
    );
  }
}