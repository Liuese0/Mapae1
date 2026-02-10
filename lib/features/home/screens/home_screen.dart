import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/nfc_service.dart';
import '../../shared/models/business_card.dart';
import '../../shared/widgets/notification_bell.dart';
import '../widgets/card_3d_widget.dart';
import '../widgets/share_bottom_sheet.dart';

// Provider for my cards list on home screen
final myCardsHomeProvider =
FutureProvider.autoDispose<List<BusinessCard>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  final user = service.currentUser;
  if (user == null) return [];
  return service.getMyCards(user.id);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _pageController = PageController(
    viewportFraction: 0.85,
  );
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showShareSheet(BusinessCard card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (context) => ShareBottomSheet(card: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myCards = ref.watch(myCardsHomeProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // App title + notification bell
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 40), // balance for bell icon
                  Expanded(
                    child: Text(
                      'NameCard',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const NotificationBell(),
                ],
              ),
            ),
            const Spacer(flex: 2),

            // 3D Card display area
            myCards.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return _buildEmptyState(theme);
                }
                return Column(
                  children: [
                    SizedBox(
                      height: 280,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: cards.length,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                        },
                        itemBuilder: (context, index) {
                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double value = 1.0;
                              if (_pageController
                                  .position.haveDimensions) {
                                value = (_pageController.page ?? 0) - index;
                                value = (1 - (value.abs() * 0.3))
                                    .clamp(0.0, 1.0);
                              }
                              return Center(
                                child: Transform.scale(
                                  scale: Curves.easeOut.transform(value),
                                  child: child,
                                ),
                              );
                            },
                            child: Card3DWidget(card: cards[index]),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Page indicator
                    if (cards.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          cards.length,
                              (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPage == index ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '좌우로 스와이프하여 다른 명함을 확인하세요',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: 280,
                child: Center(child: Text('오류: $e')),
              ),
            ),

            const Spacer(flex: 1),

            // Share button
            myCards.when(
              data: (cards) {
                if (cards.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showShareSheet(cards[_currentPage]),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('공유'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              '등록된 내 명함이 없습니다',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '관리 탭에서 내 명함을 추가해보세요',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}