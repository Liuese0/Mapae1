import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/wallet')) return 0;
    if (location.startsWith('/management')) return 2;
    return 1; // home is default center
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/wallet');
        break;
      case 1:
        context.go('/home');
        break;
      case 2:
        context.go('/management');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIdx = _currentIndex(context);

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(currentIdx),
          child: child,
        ),
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor.withOpacity(0.0),
              theme.scaffoldBackgroundColor.withOpacity(0.8),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet,
                  label: _getLabel(context, 0),
                  isActive: currentIdx == 0,
                  onTap: () => _onTap(context, 0),
                ),
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: _getLabel(context, 1),
                  isActive: currentIdx == 1,
                  onTap: () => _onTap(context, 1),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: _getLabel(context, 2),
                  isActive: currentIdx == 2,
                  onTap: () => _onTap(context, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getLabel(BuildContext context, int index) {
    switch (index) {
      case 0:
        return '지갑';
      case 1:
        return '홈';
      case 2:
        return '관리';
      default:
        return '';
    }
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _tapController.forward(),
      onTapUp: (_) {
        _tapController.reverse();
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => _tapController.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Icon(
                  widget.isActive ? widget.activeIcon : widget.icon,
                  key: ValueKey(widget.isActive),
                  color: widget.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.4),
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 11,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                child: Text(widget.label),
              ),
              // Active indicator dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(top: 3),
                width: widget.isActive ? 4 : 0,
                height: widget.isActive ? 4 : 0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}