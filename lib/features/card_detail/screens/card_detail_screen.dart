import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/collected_card.dart';
import '../../shared/models/context_tag.dart';
import '../../wallet/screens/wallet_screen.dart';

final cardDetailProvider =
FutureProvider.family.autoDispose<CollectedCard?, String>(
        (ref, cardId) async {
      final service = ref.read(supabaseServiceProvider);
      final user = service.currentUser;
      if (user == null) return null;

      final cards = await service.getCollectedCards(user.id);
      return cards.where((c) => c.id == cardId).firstOrNull;
    });

final cardTagsProvider =
FutureProvider.family.autoDispose<List<ContextTag>, String>(
        (ref, cardId) async {
      return ref.read(supabaseServiceProvider).getCardTags(cardId);
    });

class CardDetailScreen extends ConsumerWidget {
  final String cardId;

  const CardDetailScreen({super.key, required this.cardId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cardAsync = ref.watch(cardDetailProvider(cardId));
    final tagsAsync = ref.watch(cardTagsProvider(cardId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('명함 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => context.push('/card/$cardId/edit'),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade300),
            onPressed: () => _deleteCard(context, ref),
          ),
        ],
      ),
      body: cardAsync.when(
        data: (card) {
          if (card == null) {
            return const Center(child: Text('명함을 찾을 수 없습니다'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card image
                if (card.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      card.imageUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 24),

                // Name & company
                Text(
                  card.name ?? '이름 없음',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (card.company != null || card.position != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [card.company, card.position]
                          .where((s) => s != null)
                          .join(' · '),
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                if (card.department != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      card.department!,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Quick action buttons
                Row(
                  children: [
                    if (card.phone != null || card.mobile != null)
                      _QuickAction(
                        icon: Icons.call,
                        label: '전화',
                        onTap: () => _launchUrl(
                            'tel:${card.mobile ?? card.phone}'),
                      ),
                    if (card.email != null)
                      _QuickAction(
                        icon: Icons.email_outlined,
                        label: '이메일',
                        onTap: () => _launchUrl('mailto:${card.email}'),
                      ),
                    if (card.phone != null || card.mobile != null)
                      _QuickAction(
                        icon: Icons.message_outlined,
                        label: '메시지',
                        onTap: () => _launchUrl(
                            'sms:${card.mobile ?? card.phone}'),
                      ),
                    if (card.snsUrl != null)
                      _QuickAction(
                        icon: Icons.public,
                        label: 'SNS',
                        onTap: () => _launchUrl(card.snsUrl!),
                      ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Contact details
                if (card.phone != null)
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    label: '전화',
                    value: card.phone!,
                    onTap: () => _launchUrl('tel:${card.phone}'),
                  ),
                if (card.mobile != null)
                  _DetailRow(
                    icon: Icons.smartphone_outlined,
                    label: '휴대폰',
                    value: card.mobile!,
                    onTap: () => _launchUrl('tel:${card.mobile}'),
                  ),
                if (card.fax != null)
                  _DetailRow(
                    icon: Icons.fax_outlined,
                    label: '팩스',
                    value: card.fax!,
                  ),
                if (card.email != null)
                  _DetailRow(
                    icon: Icons.email_outlined,
                    label: '이메일',
                    value: card.email!,
                    onTap: () => _launchUrl('mailto:${card.email}'),
                  ),
                if (card.website != null)
                  _DetailRow(
                    icon: Icons.language,
                    label: '웹사이트',
                    value: card.website!,
                    onTap: () => _launchUrl(card.website!),
                  ),
                if (card.address != null)
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: '주소',
                    value: card.address!,
                  ),
                if (card.memo != null && card.memo!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    '메모',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(card.memo!, style: const TextStyle(fontSize: 14)),
                ],

                // Context tags
                tagsAsync.when(
                  data: (tags) {
                    if (tags.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          '상황 태그',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...tags.map((tag) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: theme
                                  .colorScheme.surfaceContainerHighest,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: tag.values.entries.map((entry) {
                                return Padding(
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          entry.key,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme
                                                .colorScheme.onSurface
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${entry.value}',
                                          style: const TextStyle(
                                              fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }

  Future<void> _deleteCard(BuildContext context, WidgetRef ref) async {
    final service = ref.read(supabaseServiceProvider);

    // 공유된 팀이 있는지 확인
    final sharedTeams = await service.getTeamsWhereCardIsShared(cardId);
    final isShared = sharedTeams.isNotEmpty;

    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('명함 삭제'),
        content: Text(
          isShared
              ? '이 명함은 ${sharedTeams.length}개 팀에 공유되어 있습니다.\n'
              '개인 지갑에서만 삭제되며, 팀 공유 명함은 유지됩니다.'
              : '이 명함을 삭제하시겠습니까?',
        ),
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
      await service.deleteCollectedCard(cardId);
      ref.invalidate(collectedCardsProvider);
      ref.invalidate(cardCountProvider);
      ref.invalidate(categoriesProvider);
      if (context.mounted) context.pop();
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.primary.withOpacity(0.08),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: onTap != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
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