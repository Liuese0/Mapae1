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
      child: IconButton(
        onPressed: () => context.push('/notifications'),
        padding: EdgeInsets.zero,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              count > 0
                  ? Icons.notifications
                  : Icons.notifications_none_outlined,
              size: 24,
            ),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
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
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}