import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/premium_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/animated_list_item.dart';
import '../../../l10n/generated/app_localizations.dart';
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

final _debouncedSearchProvider = StateProvider<String>((ref) => '');

final walletFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

final collectedCardsProvider =
FutureProvider.autoDispose<List<CollectedCard>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  final user = service.currentUser;
  if (user == null) return [];

  final sortMode = ref.watch(walletSortProvider);
  final categoryId = ref.watch(walletCategoryProvider);
  final favoritesOnly = ref.watch(walletFavoritesOnlyProvider);

  return service.getCollectedCards(
    user.id,
    categoryId: categoryId,
    sortBy: sortMode == SortMode.byName ? 'name' : 'created_at',
    ascending: sortMode == SortMode.byName,
    limit: 100,
    isFavorite: favoritesOnly ? true : null,
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
  Timer? _debounceTimer;

  // ── Selection mode state ──
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

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
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onAddPressed() {
    // 무료 플랜 명함 제한 체크
    final isPro = ref.read(isProProvider);
    if (!isPro) {
      final count = ref.read(cardCountProvider).valueOrNull ?? 0;
      if (count >= PremiumService.freeMaxCards) {
        _showCardLimitDialog();
        return;
      }
    }
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

  void _showCardLimitDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cardLimitReached),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.cardLimitMessage(PremiumService.freeMaxCards)),
            const SizedBox(height: 8),
            Text(l10n.upgradeToProForMore),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.upgradeToPro),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(walletSearchQueryProvider.notifier).state = query;
    });
  }

  // ── Selection mode methods ──

  void _enterSelectionMode(String cardId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(cardId);
    });
  }

  void _toggleSelection(String cardId) {
    setState(() {
      if (_selectedIds.contains(cardId)) {
        _selectedIds.remove(cardId);
        if (_selectedIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIds.add(cardId);
      }
    });
  }

  void _selectAll(List<CollectedCard> cards) {
    setState(() {
      _selectedIds.addAll(cards.map((c) => c.id));
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _batchDelete() async {
    final l10n = AppLocalizations.of(context);
    final count = _selectedIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.batchDelete),
        content: Text(l10n.confirmBatchDeleteCards(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final service = ref.read(supabaseServiceProvider);
    for (final id in _selectedIds) {
      await service.deleteCollectedCard(id);
    }

    ref.invalidate(collectedCardsProvider);
    ref.invalidate(cardCountProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.batchDeletedCards(count))),
      );
    }

    _exitSelectionMode();
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
    final l10n = AppLocalizations.of(context);
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
                // Header with card count (always visible)
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
                              l10n.totalCards(count),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
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

                // Search bar + filter chips (always visible)
                SearchFilterBar(
                  categories: categories.valueOrNull ?? [],
                ),

                // Card list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(collectedCardsProvider);
                      ref.invalidate(cardCountProvider);
                    },
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
                            bottom: _selectionMode ? 80 : 120,
                          ),
                          itemCount: mixedList.length,
                          itemBuilder: (context, index) {
                            final item = mixedList[index];

                            // ── 광고 슬롯 (선택 모드에서는 숨김) ──
                            if (item == null) {
                              if (_selectionMode) {
                                return const SizedBox.shrink();
                              }
                              return const NativeAdCard();
                            }

                            // ── 명함 카드 ──
                            final animIndex = cardAnimIndex++;
                            final isLast = index == mixedList.length - 1;
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
                                  selectionMode: _selectionMode,
                                  isSelected: _selectedIds.contains(item.id),
                                  onTap: _selectionMode
                                      ? () => _toggleSelection(item.id)
                                      : () => context.push('/card/${item.id}'),
                                  onLongPress: _selectionMode
                                      ? () => _toggleSelection(item.id)
                                      : () => _enterSelectionMode(item.id),
                                  onDelete: _selectionMode
                                      ? null
                                      : () async {
                                    await ref.read(supabaseServiceProvider).deleteCollectedCard(item.id);
                                    ref.invalidate(collectedCardsProvider);
                                    ref.invalidate(cardCountProvider);
                                  },
                                  onEdit: _selectionMode
                                      ? null
                                      : () => context.push('/card/${item.id}/edit'),
                                  onFavoriteToggle: _selectionMode
                                      ? null
                                      : (isFavorite) async {
                                    await ref.read(supabaseServiceProvider).toggleFavorite(item.id, isFavorite);
                                    ref.invalidate(collectedCardsProvider);
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => _buildShimmerList(hPadding),
                      error: (e, _) => Center(child: Text(l10n.errorMsg(e.toString()))),
                    ),
                  ),
                ),
              ],
            ),

            // ── Selection action bar (bottom overlay) ──
            if (_selectionMode)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildSelectionBar(theme, l10n, cards.valueOrNull ?? []),
              ),

            // Floating add button (hidden in selection mode)
            if (!_selectionMode)
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

  Widget _buildSelectionBar(
      ThemeData theme, AppLocalizations l10n, List<CollectedCard> allCards) {
    final searchQuery = ref.watch(walletSearchQueryProvider);
    final filteredList = searchQuery.isEmpty
        ? allCards
        : allCards.where((card) {
      final q = searchQuery.toLowerCase();
      return (card.name?.toLowerCase().contains(q) ?? false) ||
          (card.company?.toLowerCase().contains(q) ?? false) ||
          (card.position?.toLowerCase().contains(q) ?? false) ||
          (card.department?.toLowerCase().contains(q) ?? false) ||
          (card.email?.toLowerCase().contains(q) ?? false) ||
          (card.phone?.contains(q) ?? false) ||
          (card.mobile?.contains(q) ?? false);
    }).toList();

    final allSelected = filteredList.isNotEmpty &&
        filteredList.every((c) => _selectedIds.contains(c.id));

    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 8,
        bottom: MediaQuery.of(context).viewPadding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Close button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _exitSelectionMode,
            tooltip: l10n.cancel,
          ),
          // Selected count
          Text(
            l10n.selectedCount(_selectedIds.length),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Select all / deselect all
          TextButton(
            onPressed: () {
              if (allSelected) {
                _exitSelectionMode();
              } else {
                _selectAll(filteredList);
              }
            },
            child: Text(
              allSelected ? l10n.deselectAll : l10n.selectAll,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 4),
          // Delete button
          FilledButton.icon(
            onPressed: _selectedIds.isEmpty ? null : _batchDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(l10n.batchDelete),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.red.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList(double hPadding) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: hPadding),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
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
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noCards,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                    .withValues(alpha: _isPressed ? 0.15 : 0.3),
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