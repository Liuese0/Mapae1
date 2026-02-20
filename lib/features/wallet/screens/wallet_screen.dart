import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/animated_list_item.dart';
import '../../../core/utils/responsive.dart';
import '../../shared/models/collected_card.dart';
import '../widgets/card_list_tile.dart';
import '../widgets/scan_card_sheet.dart';
import '../widgets/search_filter_bar.dart';

enum SortMode { byDate, byName }

const int _adInterval = 5;

final walletSortProvider = StateProvider<SortMode>((ref) => SortMode.byDate);
final walletCategoryProvider = StateProvider<String?>((ref) => null);
final walletSearchQueryProvider = StateProvider<String>((ref) => '');

/// TODO: 실제 인앱결제(₩1,000 1회 구매) 연동 시 값 갱신.
final premiumAdFreeProvider = StateProvider<bool>((ref) => false);

final collectedCardsProvider =
    FutureProvider.autoDispose<List<CollectedCard>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  final user = service.currentUser;
  if (user == null) return [];

  final sortMode = ref.watch(walletSortProvider);
  final categoryId = ref.watch(walletCategoryProvider);

  return service.getCollectedCards(
    user.id,
    categoryId: categoryId,
    sortBy: sortMode == SortMode.byName ? 'name' : 'created_at',
    ascending: sortMode == SortMode.byName,
  );
});

final cardCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  final user = service.currentUser;
  if (user == null) return 0;
  return service.getCollectedCardCount(user.id);
});

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: Curves.easeOutCubic,
      ),
    );
    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  void _onAddPressed() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => ScanCardSheet(
        onScanComplete: () {
          ref.invalidate(collectedCardsProvider);
          ref.invalidate(cardCountProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ref.watch(collectedCardsProvider);
    final cardCount = ref.watch(cardCountProvider);
    final categories = ref.watch(categoriesProvider);
    final searchQuery = ref.watch(walletSearchQueryProvider);
    final isPremiumAdFree = ref.watch(premiumAdFreeProvider);
    final hPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: hPadding,
                        right: hPadding,
                        top: 12,
                        bottom: 4,
                      ),
                      child: Row(
                        children: [
                          cardCount.when(
                            data: (count) => Text(
                              '전체 명함 ${count}장',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SearchFilterBar(
                  categories: categories.valueOrNull ?? [],
                ),
                Expanded(
                  child: cards.when(
                    data: (cardList) {
                      final filteredList = searchQuery.isEmpty
                          ? cardList
                          : cardList.where((card) {
                              final q = searchQuery.toLowerCase();
                              return (card.name?.toLowerCase().contains(q) ??
                                      false) ||
                                  (card.company?.toLowerCase().contains(q) ??
                                      false) ||
                                  (card.position?.toLowerCase().contains(q) ??
                                      false) ||
                                  (card.department?.toLowerCase().contains(q) ??
                                      false) ||
                                  (card.email?.toLowerCase().contains(q) ??
                                      false) ||
                                  (card.phone?.contains(q) ?? false) ||
                                  (card.mobile?.contains(q) ?? false);
                            }).toList();

                      if (filteredList.isEmpty) {
                        return _buildEmptyState(theme);
                      }

                      final walletItems = _buildWalletItems(
                        cards: filteredList,
                        showAds: !isPremiumAdFree,
                      );

                      return ListView.separated(
                        padding: EdgeInsets.only(
                          left: hPadding,
                          right: hPadding,
                          bottom: 120,
                        ),
                        itemCount: walletItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = walletItems[index];
                          if (item.type == _WalletItemType.card) {
                            final card = item.card!;
                            return AnimatedListItem(
                              index: index,
                              child: CardListTile(
                                card: card,
                                onTap: () => context.push('/card/${card.id}'),
                              ),
                            );
                          }

                          return AnimatedListItem(
                            index: index,
                            child: const _NativeAdCard(),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('오류: $e')),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: Responsive.value(context, mobile: 90.0, tablet: 100.0),
              left: 0,
              right: 0,
              child: Center(
                child: _AnimatedFAB(
                  onTap: _onAddPressed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_WalletListItem> _buildWalletItems({
    required List<CollectedCard> cards,
    required bool showAds,
  }) {
    if (!showAds) {
      return cards.map(_WalletListItem.card).toList();
    }

    final items = <_WalletListItem>[];
    for (var i = 0; i < cards.length; i++) {
      items.add(_WalletListItem.card(cards[i]));
      final isAdSlot = (i + 1) % _adInterval == 0;
      final isNotLast = i < cards.length - 1;
      if (isAdSlot && isNotLast) {
        items.add(_WalletListItem.ad());
      }
    }
    return items;
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: child,
            ),
            child: Icon(
              Icons.credit_card_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '명함이 없습니다',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _NativeAdCard extends StatefulWidget {
  const _NativeAdCard();

  @override
  State<_NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<_NativeAdCard> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _nativeAd = NativeAd(
      adUnitId: _AdUnitIds.native,
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Colors.transparent,
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF1F2937),
          style: NativeTemplateFontStyle.medium,
          size: 12,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF111827),
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF6B7280),
          style: NativeTemplateFontStyle.normal,
          size: 12,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF9CA3AF),
          style: NativeTemplateFontStyle.normal,
          size: 11,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: theme.colorScheme.outline.withOpacity(0.25), height: 1),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Sponsored',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.45),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
          ),
          child: SizedBox(
            height: 84,
            child: AdWidget(ad: _nativeAd!),
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: theme.colorScheme.outline.withOpacity(0.25), height: 1),
      ],
    );
  }
}

enum _WalletItemType { card, ad }

class _WalletListItem {
  final _WalletItemType type;
  final CollectedCard? card;

  const _WalletListItem._({required this.type, this.card});

  factory _WalletListItem.card(CollectedCard card) =>
      _WalletListItem._(type: _WalletItemType.card, card: card);

  factory _WalletListItem.ad() => const _WalletListItem._(type: _WalletItemType.ad);
}

class _AdUnitIds {
  _AdUnitIds._();

  static String get native {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/2247696110';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/3986624511';
    }
    return '';
  }
}

/// FAB with scale micro-interaction and subtle shadow animation.
class _AnimatedFAB extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedFAB({required this.onTap});

  @override
  State<_AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<_AnimatedFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - (_controller.value * 0.1),
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(_isPressed ? 0.15 : 0.3),
                blurRadius: _isPressed ? 6 : 12,
                offset: Offset(0, _isPressed ? 2 : 4),
              ),
            ],
          ),
          child: Icon(
            Icons.add,
            color: theme.colorScheme.onPrimary,
            size: 28,
          ),
        ),
      ),
    );
  }
}
