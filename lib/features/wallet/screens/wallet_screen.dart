import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/collected_card.dart';
import '../../shared/models/category.dart';
import '../widgets/card_list_tile.dart';
import '../widgets/category_radial_menu.dart';
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

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _showCategoryMenu = false;

  void _onAddPressed() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
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

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Card count
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

                      // Sort toggle
                      GestureDetector(
                        onTap: () {
                          ref.read(walletSortProvider.notifier).state =
                          sortMode == SortMode.byDate
                              ? SortMode.byName
                              : SortMode.byDate;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border:
                            Border.all(color: theme.colorScheme.outline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sort,
                                size: 14,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                sortMode == SortMode.byDate
                                    ? '등록순'
                                    : '이름순',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Category filter chips
                if (selectedCategory != null)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, bottom: 8),
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
                            ref.read(walletCategoryProvider.notifier).state =
                            null;
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),

                // Card list
                Expanded(
                  child: cards.when(
                    data: (cardList) {
                      if (cardList.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.credit_card_off_outlined,
                                size: 48,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.2),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '명함이 없습니다',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: 120,
                        ),
                        itemCount: cardList.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return CardListTile(
                            card: cardList[index],
                            onTap: () =>
                                context.push('/card/${cardList[index].id}'),
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
                  ref.read(walletCategoryProvider.notifier).state =
                      categoryId;
                  setState(() => _showCategoryMenu = false);
                },
                onDismiss: () {
                  setState(() => _showCategoryMenu = false);
                },
              ),

            // Floating add button
            Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _onAddPressed,
                  onLongPress: _onAddLongPressed,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}