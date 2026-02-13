import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/animated_list_item.dart';
import '../../shared/models/collected_card.dart';
import '../../shared/models/category.dart';
import '../widgets/card_list_tile.dart';
import '../widgets/category_radial_menu.dart' hide AnimatedBuilder;
import '../widgets/scan_card_sheet.dart';

enum SortMode { byDate, byName }

// Wallet providers
final walletSortProvider = StateProvider<SortMode>((ref) => SortMode.byDate);
final walletCategoryProvider = StateProvider<String?>((ref) => null);

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

final categoriesProvider =
FutureProvider.autoDispose<List<CardCategory>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  final user = service.currentUser;
  if (user == null) return [];
  return service.getCategories(user.id);
});

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  bool _showCategoryMenu = false;

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

  void _onAddLongPressed() {
    setState(() => _showCategoryMenu = !_showCategoryMenu);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ref.watch(collectedCardsProvider);
    final cardCount = ref.watch(cardCountProvider);
    final sortMode = ref.watch(walletSortProvider);
    final categories = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(walletCategoryProvider);
    final hPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: hPadding,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Card count
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

                          // Sort toggle with micro-interaction
                          _AnimatedSortToggle(
                            sortMode: sortMode,
                            onTap: () {
                              ref.read(walletSortProvider.notifier).state =
                              sortMode == SortMode.byDate
                                  ? SortMode.byName
                                  : SortMode.byDate;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Category filter chips
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: selectedCategory != null
                      ? Padding(
                    padding: EdgeInsets.only(
                      left: hPadding,
                      right: hPadding,
                      bottom: 8,
                    ),
                    child: Row(
                      children: [
                        Chip(
                          label: Text(
                            categories.valueOrNull
                                ?.firstWhere(
                                    (c) => c.id == selectedCategory,
                                orElse: () => CardCategory(
                                  id: '',
                                  userId: '',
                                  name: '',
                                  createdAt: DateTime.now(),
                                ))
                                .name ??
                                '',
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () {
                            ref
                                .read(walletCategoryProvider.notifier)
                                .state = null;
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  )
                      : const SizedBox.shrink(),
                ),

                // Card list
                Expanded(
                  child: cards.when(
                    data: (cardList) {
                      if (cardList.isEmpty) {
                        return _buildEmptyState(theme);
                      }
                      return ListView.separated(
                        padding: EdgeInsets.only(
                          left: hPadding,
                          right: hPadding,
                          bottom: 120,
                        ),
                        itemCount: cardList.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return AnimatedListItem(
                            index: index,
                            child: CardListTile(
                              card: cardList[index],
                              onTap: () => context
                                  .push('/card/${cardList[index].id}'),
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

            // Category radial menu overlay
            if (_showCategoryMenu)
              CategoryRadialMenu(
                categories: categories.valueOrNull ?? [],
                onCategorySelected: (categoryId) {
                  ref.read(walletCategoryProvider.notifier).state = categoryId;
                  setState(() => _showCategoryMenu = false);
                },
                onDismiss: () {
                  setState(() => _showCategoryMenu = false);
                },
              ),

            // Floating add button with pulse animation
            Positioned(
              bottom: Responsive.value(context, mobile: 90.0, tablet: 100.0),
              left: 0,
              right: 0,
              child: Center(
                child: _AnimatedFAB(
                  onTap: _onAddPressed,
                  onLongPress: _onAddLongPressed,
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

/// Sort toggle with scale micro-interaction on tap.
class _AnimatedSortToggle extends StatefulWidget {
  final SortMode sortMode;
  final VoidCallback onTap;
  const _AnimatedSortToggle({required this.sortMode, required this.onTap});

  @override
  State<_AnimatedSortToggle> createState() => _AnimatedSortToggleState();
}

class _AnimatedSortToggleState extends State<_AnimatedSortToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - (_controller.value * 0.08),
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween(begin: 0.5, end: 1.0).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  Icons.sort,
                  key: ValueKey(widget.sortMode),
                  size: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  widget.sortMode == SortMode.byDate ? '등록순' : '이름순',
                  key: ValueKey(widget.sortMode),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// FAB with scale micro-interaction and subtle shadow animation.
class _AnimatedFAB extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _AnimatedFAB({required this.onTap, required this.onLongPress});

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
      onLongPress: widget.onLongPress,
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