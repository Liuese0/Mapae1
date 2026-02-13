import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(pendingInvitationCountProvider);
    final count = countAsync.valueOrNull ?? 0;

    return SizedBox(
      width: 40,
      height: 40,
      child: _BellButton(
        count: count,
        onPressed: () => context.push('/notifications'),
      ),
    );
  }
}

class _BellButton extends StatefulWidget {
  final int count;
  final VoidCallback onPressed;
  const _BellButton({required this.count, required this.onPressed});

  @override
  State<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<_BellButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _tapController.forward(),
      onTapUp: (_) {
        _tapController.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _tapController.reverse(),
      child: AnimatedBuilder(
        animation: _tapController,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - (_tapController.value * 0.15),
          child: child,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  widget.count > 0
                      ? Icons.notifications
                      : Icons.notifications_none_outlined,
                  key: ValueKey(widget.count > 0),
                  size: 24,
                ),
              ),
            ),
            if (widget.count > 0)
              Positioned(
                right: 2,
                top: 2,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: child,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      widget.count > 99 ? '99+' : '${widget.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
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