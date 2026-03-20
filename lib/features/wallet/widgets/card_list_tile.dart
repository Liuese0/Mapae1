import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/collected_card.dart';
import '../screens/wallet_screen.dart';

class CardListTile extends StatelessWidget {
  final CollectedCard card;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onFavoriteToggle;

  const CardListTile({
    super.key,
    required this.card,
    required this.onTap,
    this.onDelete,
    this.onEdit,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              // Left side: info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name ?? '이름 없음',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (card.company != null)
                      Text(
                        card.company!,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (card.position != null)
                      Text(
                        card.position!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (card.categoryName != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color:
                          theme.colorScheme.primary.withValues(alpha: 0.08),
                        ),
                        child: Text(
                          card.categoryName!,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Favorite toggle
              if (onFavoriteToggle != null)
                GestureDetector(
                  onTap: () => onFavoriteToggle!(!card.isFavorite),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      card.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 20,
                      color: card.isFavorite
                          ? Colors.amber
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),

              // Right side: card image thumbnail
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: card.imageUrl != null
                      ? CachedNetworkImage(
                    imageUrl: card.imageUrl!,
                    width: 80,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildPlaceholder(theme),
                    errorWidget: (_, __, ___) =>
                        _buildPlaceholder(theme),
                  )
                      : _buildPlaceholder(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Swipe 액션 래핑
    if (onDelete != null || onEdit != null) {
      tile = Dismissible(
        key: ValueKey(card.id),
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: Colors.blue.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.edit, color: Colors.white),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // 삭제 확인
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('명함 삭제'),
                content: const Text('이 명함을 삭제하시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('삭제'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              onDelete?.call();
            }
            return false; // Don't actually dismiss, let the provider refresh handle it
          } else if (direction == DismissDirection.startToEnd) {
            onEdit?.call();
            return false;
          }
          return false;
        },
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: 80,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.credit_card,
        size: 20,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
      ),
    );
  }
}