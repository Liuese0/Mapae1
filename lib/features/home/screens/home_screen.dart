import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';

import '../../../core/utils/responsive.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController(
    viewportFraction: 0.85,
  );
  int _currentPage = 0;

  late AnimationController _entranceController;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _cardFade;
  late Animation<double> _cardScale;
  late Animation<double> _buttonFade;
  late Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    ));

    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );
    _cardScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _buttonFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    _entranceController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _showShareSheet(BusinessCard card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => ShareBottomSheet(card: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myCards = ref.watch(myCardsHomeProvider);
    final cardHeight = Responsive.cardHeight(context);
    final hPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: Responsive.value(context, mobile: 12.0, tablet: 20.0)),

            // App title + notification bell
            SlideTransition(
              position: _titleSlide,
              child: FadeTransition(
                opacity: _titleFade,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Text(
                          'Mapae',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            fontSize: 18 * Responsive.fontScale(context),
                          ),
                        ),
                      ),
                      const NotificationBell(),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),

            // 3D Card display area
            FadeTransition(
              opacity: _cardFade,
              child: ScaleTransition(
                scale: _cardScale,
                child: myCards.when(
                  data: (cards) {
                    if (cards.isEmpty) {
                      return _buildEmptyState(theme);
                    }
                    return Column(
                      children: [
                        SizedBox(
                          height: cardHeight,
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
                                curve: Curves.easeInOut,
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
                            fontSize: 12 * Responsive.fontScale(context),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => SizedBox(
                    height: cardHeight,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SizedBox(
                    height: cardHeight,
                    child: Center(child: Text('오류: $e')),
                  ),
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Share button
            SlideTransition(
              position: _buttonSlide,
              child: FadeTransition(
                opacity: _buttonFade,
                child: myCards.when(
                  data: (cards) {
                    if (cards.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.value(context, mobile: 48.0, tablet: 120.0),
                      ),
                      child: SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: _AnimatedShareButton(
                          onPressed: () => _showShareSheet(cards[_currentPage]),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            SizedBox(height: Responsive.value(context, mobile: 100.0, tablet: 120.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SizedBox(
      height: Responsive.cardHeight(context),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: Icon(
                Icons.credit_card_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.2),
              ),
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

/// Share button with scale-on-tap micro-interaction.
class _AnimatedShareButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AnimatedShareButton({required this.onPressed});

  @override
  State<_AnimatedShareButton> createState() => _AnimatedShareButtonState();
}

class _AnimatedShareButtonState extends State<_AnimatedShareButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.share_outlined, size: 18),
          label: const Text('공유'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            disabledForegroundColor: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}