import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/animated_list_item.dart';
import '../../shared/models/collected_card.dart';
import '../widgets/card_list_tile.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/scan_card_sheet.dart';
import '../widgets/search_filter_bar.dart';

enum SortMode { byDate, byName }

// Wallet providers
final walletSortProvider = StateProvider<SortMode>((ref) => SortMode.byDate);
final walletCategoryProvider = StateProvider<String?>((ref) => null);
final walletSearchQueryProvider = StateProvider<String>((ref) => '');

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
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));
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

  /// 명함 리스트에 광고 슬롯을 삽입한 혼합 아이템 목록을 생성합니다.
  ///
  /// 프리미엄 사용자이면 광고 없이 반환.
  /// 그 외에는 맨 위 + 5번째 카드마다 뒤에 광고 슬롯(null)을 삽입.
  List<CollectedCard?> _buildMixedList(
    List<CollectedCard> cards,
    bool isPremium,
  ) {
    if (isPremium) {
      return List<CollectedCard?>.from(cards);
    }
    final List<CollectedCard?> mixed = [null]; // 첫 번째 카드 위 광고 슬롯
    for (int i = 0; i < cards.length; i++) {
      mixed.add(cards[i]);
      // 5번째 카드(인덱스 4, 9, 14 …) 뒤에 광고 슬롯 삽입
      if ((i + 1) % 5 == 0) {
        mixed.add(null);
      }
    }
    return mixed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ref.watch(collectedCardsProvider);
    final cardCount = ref.watch(cardCountProvider);
    final categories = ref.watch(categoriesProvider);
    final searchQuery = ref.watch(walletSearchQueryProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final hPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header with card count
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
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
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

                // Search bar + filter chips
                SearchFilterBar(
                  categories: categories.valueOrNull ?? [],
                ),

                // Card list
                Expanded(
                  child: cards.when(
                    data: (cardList) {
                      // Apply client-side search filtering
                      final filteredList = searchQuery.isEmpty
                          ? cardList
                          : cardList.where((card) {
                        final q = searchQuery.toLowerCase();
                        return (card.name?.toLowerCase().contains(q) ?? false) ||
                            (card.company?.toLowerCase().contains(q) ?? false) ||
                            (card.position?.toLowerCase().contains(q) ?? false) ||
                            (card.department?.toLowerCase().contains(q) ?? false) ||
                            (card.email?.toLowerCase().contains(q) ?? false) ||
                            (card.phone?.contains(q) ?? false) ||
                            (card.mobile?.contains(q) ?? false);
                      }).toList();

                      if (filteredList.isEmpty) {
                        return _buildEmptyState(theme);
                      }

                      // 광고 슬롯(null)이 포함된 혼합 리스트
                      final mixedList = _buildMixedList(filteredList, isPremium);
                      // 애니메이션 인덱스는 실제 카드 순번 기준
                      int cardAnimIndex = 0;

                      return ListView.builder(
                        padding: EdgeInsets.only(
                          left: hPadding,
                          right: hPadding,
                          bottom: 120,
                        ),
                        itemCount: mixedList.length,
                        itemBuilder: (context, index) {
                          final item = mixedList[index];

                          // ── 광고 슬롯 ──
                          if (item == null) {
                            return const NativeAdCard();
                          }

                          // ── 명함 카드 ──
                          final animIndex = cardAnimIndex++;
                          final isLast = index == mixedList.length - 1;
                          // 다음 아이템이 광고이면 간격을 NativeAdCard가 처리하므로 축소
                          final nextIsAd = !isLast &&
                              index + 1 < mixedList.length &&
                              mixedList[index + 1] == null;

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: isLast
                                  ? 0
                                  : nextIsAd
                                      ? 4
                                      : 8,
                            ),
                            child: AnimatedListItem(
                              index: animIndex,
                              child: CardListTile(
                                card: item,
                                onTap: () =>
                                    context.push('/card/${item.id}'),
                              ),
                            ),
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

            // Floating add button with pulse animation
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
                color: theme.colorScheme.primary
                    .withOpacity(_isPressed ? 0.15 : 0.3),
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
