import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/animated_list_item.dart';
import '../../shared/models/business_card.dart';
import '../../shared/models/team.dart';
import '../../shared/widgets/notification_bell.dart';
import '../../../core/services/premium_service.dart';
import '../../../l10n/generated/app_localizations.dart';

final myCardsManageProvider =
FutureProvider.autoDispose<List<BusinessCard>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  final user = service.currentUser;
  if (user == null) return [];
  return service.getMyCards(user.id);
});

final myTeamsProvider = FutureProvider.autoDispose<List<Team>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  final user = service.currentUser;
  if (user == null) return [];
  return service.getUserTeams(user.id);
});

class ManagementScreen extends ConsumerStatefulWidget {
  const ManagementScreen({super.key});

  @override
  ConsumerState<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends ConsumerState<ManagementScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(-0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final myCards = ref.watch(myCardsManageProvider);
    final myTeams = ref.watch(myTeamsProvider);
    final hPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const SizedBox(height: 16),
            SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.management,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 24 * Responsive.fontScale(context),
                        ),
                      ),
                      const NotificationBell(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // My Cards Section
            AnimatedListItem(
              index: 0,
              child: _SectionHeader(
                title: l10n.myCards,
                actionLabel: l10n.addCard,
                onAction: () => context.push('/my-card/edit'),
                padding: hPadding,
              ),
            ),
            const SizedBox(height: 8),
            myCards.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return AnimatedListItem(
                    index: 1,
                    child: _EmptyBox(
                      icon: Icons.credit_card_outlined,
                      message: '등록된 내 명함이 없습니다',
                      actionLabel: '명함 추가',
                      onAction: () => context.push('/my-card/edit'),
                      padding: hPadding,
                    ),
                  );
                }
                return Column(
                  children: cards.asMap().entries.map((entry) {
                    return AnimatedListItem(
                      index: entry.key + 1,
                      child: _MyCardTile(
                        card: entry.value,
                        onTap: () => context
                            .push('/my-card/edit?id=${entry.value.id}'),
                        onDelete: () async {
                          final confirm = await _showDeleteDialog(context);
                          if (confirm == true) {
                            await ref
                                .read(supabaseServiceProvider)
                                .deleteMyCard(entry.value.id);
                            ref.invalidate(myCardsManageProvider);
                          }
                        },
                        padding: hPadding,
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('오류: $e'),
              ),
            ),

            const SizedBox(height: 32),

            // Team Section
            AnimatedListItem(
              index: 3,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '팀',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _showJoinTeamDialog(context, ref),
                          child: const Text('팀 참가', style: TextStyle(fontSize: 13)),
                        ),
                        TextButton(
                          onPressed: () => _showCreateTeamDialog(context, ref),
                          child: const Text('만들기', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            myTeams.when(
              data: (teams) {
                if (teams.isEmpty) {
                  return AnimatedListItem(
                    index: 4,
                    child: _EmptyBox(
                      icon: Icons.group_outlined,
                      message: '소속된 팀이 없습니다',
                      actionLabel: '팀 만들기',
                      onAction: () => _showCreateTeamDialog(context, ref),
                      padding: hPadding,
                    ),
                  );
                }
                return Column(
                  children: teams.asMap().entries.map((entry) {
                    return AnimatedListItem(
                      index: entry.key + 4,
                      child: _TeamTile(
                        team: entry.value,
                        onTap: () => context.push('/team/${entry.value.id}'),
                        padding: hPadding,
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('오류: $e'),
              ),
            ),

            const SizedBox(height: 32),

            // Tag Templates
            AnimatedListItem(
              index: 6,
              child: _SectionHeader(
                title: '상황 태그 템플릿',
                actionLabel: '관리',
                onAction: () => context.push('/tag-templates'),
                padding: hPadding,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedListItem(
              index: 7,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                child: _TapScaleWidget(
                  onTap: () => context.push('/tag-templates'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.label_outlined,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '명함에 만난 상황, 특이사항 등을 기록할 태그 형식을 관리합니다',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color:
                          theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Settings
            AnimatedListItem(
              index: 8,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                child: Text(
                  l10n.settings,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Personal info
            AnimatedListItem(
              index: 9,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 4),
                child: _TapScaleWidget(
                  onTap: () => context.push('/profile'),
                  child: Row(
                    children: [
                      Icon(Icons.person_outlined, size: 20,
                          color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.profile, style: const TextStyle(fontSize: 15)),
                      ),
                      Icon(Icons.chevron_right,
                          color: theme.colorScheme.onSurface.withOpacity(0.3)),
                    ],
                  ),
                ),
              ),
            ),

            // Language
            AnimatedListItem(
              index: 10,
              child: _SettingsTile(
                icon: Icons.language,
                title: l10n.language,
                trailing: _LanguageDropdown(),
                padding: hPadding,
              ),
            ),

            // Dark mode
            AnimatedListItem(
              index: 11,
              child: _SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: l10n.darkMode,
                trailing: Consumer(
                  builder: (context, ref, _) {
                    final themeMode = ref.watch(themeModeProvider);
                    return Switch(
                      value: themeMode == ThemeMode.dark,
                      onChanged: (value) {
                        ref.read(themeModeProvider.notifier).state =
                        value ? ThemeMode.dark : ThemeMode.light;
                      },
                    );
                  },
                ),
                padding: hPadding,
              ),
            ),

            // Remove Ads (Premium)
            AnimatedListItem(
              index: 12,
              child: _PremiumTile(padding: hPadding),
            ),

            // Logout
            AnimatedListItem(
              index: 12,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: hPadding, vertical: 8),
                child: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.logout),
                        content: Text(l10n.logoutConfirm),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(l10n.cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(l10n.logout),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(autoLoginServiceProvider).clear();
                      await ref.read(supabaseServiceProvider).signOut();
                      if (context.mounted) context.go('/login');
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                  ),
                  child: Text(l10n.logout),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
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
  }

  void _showCreateTeamDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('팀 만들기'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '팀 이름'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final service = ref.read(supabaseServiceProvider);
              final user = service.currentUser;
              if (user == null) return;

              final team = Team(
                id: '',
                name: controller.text.trim(),
                ownerId: user.id,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await service.createTeam(team, user.id);
              ref.invalidate(myTeamsProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }

  void _showJoinTeamDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('팀 참가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '팀 공유코드를 입력하면 팀에 Observer로 참가합니다.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z2-9]')),
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  hintText: '공유코드 8자리',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final code = controller.text.trim();
                      if (code.length < 8) return;
                      setDialogState(() => isLoading = true);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        final result = await service.joinTeamByShareCode(code);
                        ref.invalidate(myTeamsProvider);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        final teamName = result['team_name'] as String? ?? '팀';
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('\'$teamName\'에 Observer로 참가했습니다')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (dialogContext.mounted) {
                          String message = '참가 실패: 올바른 공유코드를 입력해주세요';
                          final errorStr = e.toString();
                          if (errorStr.contains('Already a member')) {
                            message = '이미 해당 팀의 멤버입니다';
                          } else if (errorStr.contains('Invalid or inactive')) {
                            message = '유효하지 않거나 비활성화된 공유코드입니다';
                          }
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('참가'),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────── Helper Widgets ────────────────

/// Generic tap-to-scale micro-interaction wrapper.
class _TapScaleWidget extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _TapScaleWidget({required this.onTap, required this.child});

  @override
  State<_TapScaleWidget> createState() => _TapScaleWidgetState();
}

class _TapScaleWidgetState extends State<_TapScaleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          scale: 1.0 - (_controller.value * 0.03),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double padding;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double padding;

  const _EmptyBox({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.padding = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.5),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
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
                icon,
                size: 36,
                color: theme.colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MyCardTile extends StatelessWidget {
  final BusinessCard card;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final double padding;

  const _MyCardTile({
    required this.card,
    required this.onTap,
    required this.onDelete,
    this.padding = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
      child: _TapScaleWidget(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name ?? '이름 없음',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (card.company != null)
                      Text(
                        '${card.company} ${card.position ?? ""}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onTap,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red.shade300,
                ),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  final Team team;
  final VoidCallback onTap;
  final double padding;

  const _TeamTile({
    required this.team,
    required this.onTap,
    this.padding = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
      child: _TapScaleWidget(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(
                Icons.group,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  team.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  final double padding;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.padding = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20,
              color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 15)),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _LanguageDropdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);
    return DropdownButton<String>(
      value: locale.languageCode,
      underline: const SizedBox.shrink(),
      items: [
        DropdownMenuItem(value: 'ko', child: Text(l10n.korean)),
        DropdownMenuItem(value: 'en', child: Text(l10n.english)),
      ],
      onChanged: (value) {
        if (value != null) {
          ref.read(localeProvider.notifier).setLocale(Locale(value));
        }
      },
    );
  }
}

// ──────────────── Premium Tile ────────────────

/// 설정 리스트의 광고 제거 항목.
/// 프리미엄 상태에 따라 UI가 달라집니다.
class _PremiumTile extends ConsumerWidget {
  final double padding;
  const _PremiumTile({this.padding = 20});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPremium = ref.watch(isPremiumProvider);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
      child: isPremium
          ? _buildPremiumActive(theme)
          : _buildPremiumInactive(context, ref, theme),
    );
  }

  Widget _buildPremiumActive(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.star_rounded,
          size: 20,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '광고 제거',
            style: const TextStyle(fontSize: 15),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: theme.colorScheme.onSurface.withOpacity(0.06),
          ),
          child: Text(
            '적용됨',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.45),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumInactive(
      BuildContext context,
      WidgetRef ref,
      ThemeData theme,
      ) {
    return _TapScaleWidget(
      onTap: () => _showPremiumSheet(context, ref),
      child: Row(
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: 20,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '광고 제거',
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.primary.withOpacity(0.08),
            ),
            child: Text(
              '₩1,000',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  void _showPremiumSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PremiumBottomSheet(ref: ref),
    );
  }
}

// ──────────────── Premium Bottom Sheet ────────────────

class _PremiumBottomSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _PremiumBottomSheet({required this.ref});

  @override
  ConsumerState<_PremiumBottomSheet> createState() =>
      _PremiumBottomSheetState();
}

class _PremiumBottomSheetState extends ConsumerState<_PremiumBottomSheet> {
  bool _isLoading = false;

  Future<void> _handlePurchase() async {
    setState(() => _isLoading = true);

    final error = await ref.read(isPremiumProvider.notifier).purchase();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showError(error);
    }
    // 성공 시 구매 스트림에서 자동으로 isPremiumProvider 업데이트됨
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    await ref.read(isPremiumProvider.notifier).restore();
    if (!mounted) return;
    setState(() => _isLoading = false);

    final isPremium = ref.read(isPremiumProvider);
    if (isPremium && mounted) {
      Navigator.of(context).pop();
    } else {
      _showError('복원할 구매 내역이 없습니다.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = ref.watch(isPremiumProvider);

    // 구매 완료 후 시트 닫기
    if (isPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 헤더 ──
              Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 22,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '광고 없는 Mapae',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '명함 리스트의 광고를 영구적으로 제거합니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // ── 혜택 목록 ──
              _BenefitRow(
                icon: Icons.block_rounded,
                text: '명함 리스트 광고 완전 제거',
                theme: theme,
              ),
              const SizedBox(height: 10),
              _BenefitRow(
                icon: Icons.all_inclusive_rounded,
                text: '1회 결제 · 평생 적용',
                theme: theme,
              ),
              const SizedBox(height: 10),
              _BenefitRow(
                icon: Icons.devices_rounded,
                text: '동일 계정 기기 복원 가능',
                theme: theme,
              ),
              const SizedBox(height: 28),

              // ── 구매 버튼 ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handlePurchase,
                  child: _isLoading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('₩1,000 · 광고 제거'),
                ),
              ),
              const SizedBox(height: 10),

              // ── 복원 버튼 ──
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _handleRestore,
                  child: Text(
                    '이전 구매 복원',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
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

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeData theme;

  const _BenefitRow({
    required this.icon,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: theme.colorScheme.onSurface.withOpacity(0.55),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.75),
          ),
        ),
      ],
    );
  }
}