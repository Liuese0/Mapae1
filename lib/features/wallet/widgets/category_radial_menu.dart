import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../shared/models/category.dart';

class CategoryRadialMenu extends StatefulWidget {
  final List<CardCategory> categories;
  final Function(String categoryId) onCategorySelected;
  final VoidCallback onDismiss;

  const CategoryRadialMenu({
    super.key,
    required this.categories,
    required this.onCategorySelected,
    required this.onDismiss,
  });

  @override
  State<CategoryRadialMenu> createState() => _CategoryRadialMenuState();
}

class _CategoryRadialMenuState extends State<CategoryRadialMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height - 120; // near the add button
    const radius = 100.0;

    final itemCount = widget.categories.length;
    if (itemCount == 0) {
      return GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Center(
            child: Text(
              '카테고리가 없습니다',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              children: List.generate(itemCount, (index) {
                // Spread items in an arc above the button
                final angleRange = math.min(math.pi, itemCount * 0.4);
                final startAngle = math.pi + (math.pi - angleRange) / 2;
                final angle = startAngle +
                    (angleRange / (itemCount > 1 ? itemCount - 1 : 1)) *
                        index;

                final progress = _controller.value;
                final x = centerX + radius * math.cos(angle) * progress;
                final y = centerY + radius * math.sin(angle) * progress;

                return Positioned(
                  left: x - 36,
                  top: y - 18,
                  child: Opacity(
                    opacity: progress,
                    child: GestureDetector(
                      onTap: () => widget.onCategorySelected(
                          widget.categories[index].id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.categories[index].name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

/// Simple animated builder helper
class AnimatedBuilder extends StatelessWidget {
  final Listenable animation;
  final TransitionBuilder builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: builder,
      child: child,
    );
  }
}
