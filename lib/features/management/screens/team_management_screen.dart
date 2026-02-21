import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/models/team.dart';
import '../../shared/models/collected_card.dart';
import '../../shared/models/category.dart';
import '../../shared/models/crm_contact.dart';
import '../../shared/widgets/invite_member_dialog.dart';

class TeamManagementScreen extends ConsumerStatefulWidget {
  final String teamId;

  const TeamManagementScreen({super.key, required this.teamId});

  @override
  ConsumerState<TeamManagementScreen> createState() =>
      _TeamManagementScreenState();
}

class _TeamManagementScreenState extends ConsumerState<TeamManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TeamRole? _myRole;
  List<TeamMember> _members = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMyRole();
  }

  Future<void> _loadMyRole() async {
    final service = ref.read(supabaseServiceProvider);
    final userId = service.currentUser?.id;
    if (userId == null) return;
    final members = await service.getTeamMembers(widget.teamId);
    final me = members.where((m) => m.userId == userId).firstOrNull;
    if (mounted) {
      setState(() {
        _myRole = me?.role;
        _members = members;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = ref.read(supabaseServiceProvider);
    final currentUserId = service.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(AppLocalizations.of(context).teamManagement),
        actions: [
          if (_myRole != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'delete') {
                  _showDeleteTeamDialog(context, service);
                } else if (value == 'leave') {
                  _showLeaveTeamDialog(context, service, currentUserId!);
                }
              },
              itemBuilder: (context) {
                final l10n = AppLocalizations.of(context);
                if (_myRole == TeamRole.owner) {
                  return [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.deleteTeam, style: const TextStyle(color: Colors.red)),
                    ),
                  ];
                } else {
                  return [
                    PopupMenuItem(
                      value: 'leave',
                      child: Text(l10n.leaveTeam, style: const TextStyle(color: Colors.red)),
                    ),
                  ];
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.4),
          indicatorColor: theme.colorScheme.primary,
          tabs: [
            Tab(text: AppLocalizations.of(context).sharedCards),
            Tab(text: AppLocalizations.of(context).teamMembers),
            const Tab(text: 'CRM'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SharedCardsTab(
            teamId: widget.teamId,
            myRole: _myRole,
            onRefresh: _loadMyRole,
          ),
          _MembersTab(
            teamId: widget.teamId,
            myRole: _myRole,
            onRefresh: _loadMyRole,
          ),
          _CrmTab(teamId: widget.teamId, myRole: _myRole),
        ],
      ),
    );
  }

  void _showDeleteTeamDialog(BuildContext context, SupabaseService service) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTeam),
        content: Text(l10n.deleteTeamConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              await service.deleteTeam(widget.teamId);
              if (context.mounted) Navigator.pop(context);
              if (this.context.mounted) this.context.go('/management');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showLeaveTeamDialog(
      BuildContext context, SupabaseService service, String userId) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveTeam),
        content: Text(l10n.leaveTeamConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              await service.leaveTeam(widget.teamId, userId);
              if (context.mounted) Navigator.pop(context);
              if (this.context.mounted) this.context.go('/management');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
  }
}

// ──────────────── Shared Cards Tab ────────────────

class _SharedCardsTab extends ConsumerStatefulWidget {
  final String teamId;
  final TeamRole? myRole;
  final VoidCallback onRefresh;

  const _SharedCardsTab({
    required this.teamId,
    required this.myRole,
    required this.onRefresh,
  });

  @override
  ConsumerState<_SharedCardsTab> createState() => _SharedCardsTabState();
}

class _SharedCardsTabState extends ConsumerState<_SharedCardsTab> {
  List<Map<String, dynamic>>? _cards;
  List<CardCategory> _teamCategories = [];
  bool _loading = true;
  String? _filterCategoryId; // null = 전체

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _loading = true);
    final service = ref.read(supabaseServiceProvider);
    final cards = await service.getTeamSharedCards(widget.teamId);
    final categories = await service.getTeamCategories(widget.teamId);
    if (mounted) {
      setState(() {
        _cards = cards;
        _teamCategories = categories;
        _loading = false;
      });
    }
  }

  bool get _isOwner => widget.myRole == TeamRole.owner;

  bool get _canShare =>
      widget.myRole == TeamRole.owner || widget.myRole == TeamRole.member;

  List<Map<String, dynamic>> get _filteredCards {
    final cards = _cards ?? [];
    if (_filterCategoryId == null) return cards;
    return cards.where((c) => c['category_id'] == _filterCategoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final cards = _filteredCards;

    return Column(
      children: [
        // Category filter chips
        if (_teamCategories.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildCategoryChip(null, AppLocalizations.of(context).allCategories, theme),
                ..._teamCategories.map((cat) =>
                    _buildCategoryChip(cat.id, cat.name, theme)),
                if (_isOwner) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ActionChip(
                      avatar: Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                      label: Text(AppLocalizations.of(context).add, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
                      onPressed: () => _showCreateCategoryDialog(context),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ActionChip(
                      avatar: Icon(Icons.settings, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      label: Text(AppLocalizations.of(context).manage, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                      onPressed: () => _showManageCategoriesSheet(),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.2)),
                    ),
                  ),
                ],
              ],
            ),
          )
        else if (_isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: ActionChip(
                avatar: Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                label: Text(AppLocalizations.of(context).createTeamCategory, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
                onPressed: () => _showCreateCategoryDialog(context),
                side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
              ),
            ),
          ),

        Expanded(
          child: cards.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_shared_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  _filterCategoryId != null
                      ? AppLocalizations.of(context).noCardsInCategory
                      : AppLocalizations.of(context).noSharedCards,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          )
              : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final card = cards[index];
              final name = card['name'] as String? ?? AppLocalizations.of(context).noName;
              final company = card['company'] as String?;
              final position = card['position'] as String?;
              final cardCategoryId = card['category_id'] as String?;
              final categoryName = _teamCategories
                  .where((c) => c.id == cardCategoryId)
                  .map((c) => c.name)
                  .firstOrNull;

              return ListTile(
                title: Text(name),
                subtitle: Text(
                  [
                    if (categoryName != null) '[$categoryName]',
                    company,
                    position,
                  ].where((s) => s != null).join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_canShare && _teamCategories.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          cardCategoryId != null
                              ? Icons.label
                              : Icons.label_outline,
                          size: 18,
                          color: cardCategoryId != null
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        tooltip: AppLocalizations.of(context).assignCategory,
                        onPressed: () => _showAssignCategorySheet(card),
                      ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: AppLocalizations.of(context).wallet,
                      onPressed: () => _copyToWallet(card),
                    ),
                    if (_canShare)
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                        tooltip: AppLocalizations.of(context).unshareTitle,
                        onPressed: () => _unshareCard(card),
                      ),
                  ],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
              );
            },
          ),
        ),
        if (_canShare)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showShareCardDialog(context),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: Text(AppLocalizations.of(context).shareCardAction),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryChip(String? categoryId, String label, ThemeData theme) {
    final selected = _filterCategoryId == categoryId;
    final chip = FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) {
        setState(() => _filterCategoryId = categoryId);
      },
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );

    // 카테고리 칩 길게 누르면 삭제 (전체 칩 제외, owner만)
    if (categoryId != null && _isOwner) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onLongPress: () => _showDeleteCategoryDialog(categoryId, label),
          child: chip,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: chip,
    );
  }

  void _showManageCategoriesSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(AppLocalizations.of(ctx).categoryManagement,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
            ),
            ..._teamCategories.map((cat) {
              return ListTile(
                leading: Icon(Icons.label_outline,
                    color: theme.colorScheme.onSurface.withOpacity(0.5)),
                title: Text(cat.name),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.7), size: 20),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDeleteCategoryDialog(cat.id, cat.name);
                  },
                ),
              );
            }),
            if (_teamCategories.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(AppLocalizations.of(ctx).noCategories,
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4))),
              ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        );
      },
    );
  }

  void _showDeleteCategoryDialog(String categoryId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).deleteCategoryTitle),
        content: Text(AppLocalizations.of(ctx).deleteCategoryConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx).cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteTeamCategory(categoryId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(ctx).delete),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTeamCategory(String categoryId) async {
    try {
      await ref.read(supabaseServiceProvider).deleteCategory(categoryId);
      if (_filterCategoryId == categoryId) {
        _filterCategoryId = null;
      }
      ref.invalidate(teamCategoriesProvider(widget.teamId));
      await _loadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).categoryDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).categoryDeleteFailed(e.toString()))),
        );
      }
    }
  }

  void _showCreateCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).addCategoryTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(ctx).categoryName,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onSubmitted: (_) async {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            await _createTeamCategory(name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx).cancel),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _createTeamCategory(name);
            },
            child: Text(AppLocalizations.of(ctx).add),
          ),
        ],
      ),
    );
  }

  Future<void> _createTeamCategory(String name) async {
    try {
      final service = ref.read(supabaseServiceProvider);
      final userId = service.currentUser?.id;
      if (userId == null) return;

      await service.createTeamCategory(
        CardCategory(
          id: '',
          userId: userId,
          name: name,
          teamId: widget.teamId,
          createdAt: DateTime.now(),
        ),
      );
      ref.invalidate(teamCategoriesProvider(widget.teamId));
      await _loadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).categoryAdded(name))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).categoryCreateFailed(e.toString()))),
        );
      }
    }
  }

  void _showAssignCategorySheet(Map<String, dynamic> card) {
    final currentCategoryId = card['category_id'] as String?;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(AppLocalizations.of(ctx).assignCategory,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
            ),
            ListTile(
              leading: Icon(Icons.label_off_outlined,
                  color: currentCategoryId == null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.5)),
              title: Text(AppLocalizations.of(ctx).cancel,
                  style: TextStyle(
                    fontWeight: currentCategoryId == null
                        ? FontWeight.w600 : FontWeight.w400,
                    color: currentCategoryId == null
                        ? theme.colorScheme.primary : null,
                  )),
              trailing: currentCategoryId == null
                  ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                  : null,
              onTap: () async {
                Navigator.pop(ctx);
                await _assignCategory(card, null);
              },
            ),
            ..._teamCategories.map((cat) {
              final selected = cat.id == currentCategoryId;
              return ListTile(
                leading: Icon(Icons.label_outline,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.5)),
                title: Text(cat.name,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? theme.colorScheme.primary : null,
                    )),
                trailing: selected
                    ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _assignCategory(card, cat.id);
                },
              );
            }),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        );
      },
    );
  }

  Future<void> _assignCategory(Map<String, dynamic> card, String? categoryId) async {
    try {
      final sharedCardId = card['id'] as String;
      await ref.read(supabaseServiceProvider)
          .updateSharedCardCategory(sharedCardId, categoryId);
      await _loadCards();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).categoryAssignFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _unshareCard(Map<String, dynamic> card) async {
    final name = card['name'] as String? ?? AppLocalizations.of(context).noName;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).unshareTitle),
        content: Text(AppLocalizations.of(ctx).unshareConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(ctx).remove),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final sharedCardId = card['id'] as String;
        await ref.read(supabaseServiceProvider).unshareCardFromTeam(sharedCardId);
        await _loadCards();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).unshareSuccess)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).unshareFailed(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _copyToWallet(Map<String, dynamic> card) async {
    try {
      final service = ref.read(supabaseServiceProvider);
      final userId = service.currentUser?.id;
      if (userId == null) return;

      // 이미 동일한 명함이 지갑에 있는지 확인
      final existing = await service.getCollectedCards(userId);
      final duplicate = existing.where((c) =>
      c.name == card['name'] &&
          c.company == card['company'] &&
          c.position == card['position'] &&
          c.email == card['email'] &&
          c.phone == card['phone'] &&
          c.mobile == card['mobile']).firstOrNull;

      if (duplicate != null && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(ctx).duplicateCard),
            content: Text(AppLocalizations.of(ctx).duplicateCardConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(ctx).cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(ctx).copy),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }

      await service.copySharedCardToWallet(card);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).copyToWalletSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).copyFailed(e.toString()))),
        );
      }
    }
  }

  void _showShareCardDialog(BuildContext context) async {
    final service = ref.read(supabaseServiceProvider);
    final userId = service.currentUser?.id;
    if (userId == null) return;

    final myCards = await service.getCollectedCards(userId);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppLocalizations.of(dialogContext).selectCardToShare),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: myCards.isEmpty
                ? Center(child: Text(AppLocalizations.of(dialogContext).noCardsInWallet))
                : ListView.builder(
              itemCount: myCards.length,
              itemBuilder: (context, index) {
                final card = myCards[index];
                return ListTile(
                  title: Text(card.name ?? AppLocalizations.of(context).noName),
                  subtitle: Text(
                    [card.company, card.position]
                        .where((s) => s != null)
                        .join(' · '),
                  ),
                  onTap: () async {
                    // 이미 공유된 명함인지 확인 (card_id로 비교)
                    final alreadyShared = (_cards ?? [])
                        .any((c) => c['card_id'] == card.id);
                    if (alreadyShared) {
                      Navigator.pop(dialogContext);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                              content: Text(AppLocalizations.of(this.context).alreadyShared)),
                        );
                      }
                      return;
                    }
                    Navigator.pop(dialogContext);

                    // Owner면 카테고리 선택 후 공유
                    if (_canShare && _teamCategories.isNotEmpty) {
                      _showCategorySelectThenShare(card);
                    } else {
                      await _shareCard(card.id, null);
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(dialogContext).cancel),
            ),
          ],
        );
      },
    );
  }

  void _showCategorySelectThenShare(CollectedCard card) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(AppLocalizations.of(ctx).categorySelectOptional,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
            ),
            ListTile(
              leading: Icon(Icons.label_off_outlined,
                  color: theme.colorScheme.onSurface.withOpacity(0.5)),
              title: Text(AppLocalizations.of(ctx).shareWithoutCategory),
              onTap: () async {
                Navigator.pop(ctx);
                await _shareCard(card.id, null);
              },
            ),
            ..._teamCategories.map((cat) => ListTile(
              leading: Icon(Icons.label_outline,
                  color: theme.colorScheme.primary),
              title: Text(cat.name),
              onTap: () async {
                Navigator.pop(ctx);
                await _shareCard(card.id, cat.id);
              },
            )),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        );
      },
    );
  }

  Future<void> _shareCard(String cardId, String? categoryId) async {
    try {
      await ref.read(supabaseServiceProvider)
          .shareCardToTeam(cardId, widget.teamId, categoryId: categoryId);
      await _loadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).teamSharedSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).shareFailed(e.toString()))),
        );
      }
    }
  }
}

// ──────────────── Members Tab ────────────────

class _MembersTab extends ConsumerStatefulWidget {
  final String teamId;
  final TeamRole? myRole;
  final VoidCallback onRefresh;

  const _MembersTab({
    required this.teamId,
    required this.myRole,
    required this.onRefresh,
  });

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  List<TeamMember>? _members;
  Team? _team;
  bool _loading = true;
  bool _shareCodeLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final service = ref.read(supabaseServiceProvider);
    final results = await Future.wait([
      service.getTeamMembers(widget.teamId),
      service.getTeam(widget.teamId),
    ]);
    if (mounted) {
      setState(() {
        _members = results[0] as List<TeamMember>;
        _team = results[1] as Team?;
        _loading = false;
      });
    }
  }

  bool get _isOwner => widget.myRole == TeamRole.owner;
  bool get _isMember =>
      widget.myRole == TeamRole.owner || widget.myRole == TeamRole.member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final members = _members ?? [];

    return Column(
      children: [
        // ── 팀 공유코드 섹션 (오너·멤버만 표시) ──
        if (_isMember && _team != null)
          _ShareCodeSection(
            team: _team!,
            isOwner: _isOwner,
            isLoading: _shareCodeLoading,
            onToggle: (enabled) => _toggleShareCode(enabled),
            onRegenerate: _regenerateShareCode,
          ),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                  theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    member.role == TeamRole.owner
                        ? Icons.star
                        : member.role == TeamRole.member
                        ? Icons.person
                        : Icons.visibility,
                    color: member.role == TeamRole.owner
                        ? Colors.amber
                        : theme.colorScheme.primary,
                  ),
                ),
                title: Text(member.userName ?? member.userId),
                subtitle: Text(_roleDisplayName(member.role)),
                trailing: _isOwner && member.role != TeamRole.owner
                    ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) =>
                      _onMemberAction(value, member),
                  itemBuilder: (context) {
                    final items = <PopupMenuItem<String>>[];
                    final l10n = AppLocalizations.of(context);
                    if (member.role == TeamRole.observer) {
                      items.add(PopupMenuItem(
                        value: 'promote_member',
                        child: Text(l10n.promoteMember),
                      ));
                    } else if (member.role == TeamRole.member) {
                      items.add(PopupMenuItem(
                        value: 'demote_observer',
                        child: Text(l10n.demoteToObserver),
                      ));
                    }
                    items.add(PopupMenuItem(
                      value: 'transfer_owner',
                      child: Text(l10n.transferOwnership),
                    ));
                    items.add(PopupMenuItem(
                      value: 'kick',
                      child: Text(l10n.kickFromTeam,
                          style: const TextStyle(color: Colors.red)),
                    ));
                    return items;
                  },
                )
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showInviteDialog(),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text(AppLocalizations.of(context).inviteMember),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleShareCode(bool enabled) async {
    setState(() => _shareCodeLoading = true);
    try {
      await ref.read(supabaseServiceProvider)
          .toggleTeamShareCode(widget.teamId, enabled: enabled);
      final updated = await ref.read(supabaseServiceProvider).getTeam(widget.teamId);
      if (mounted) setState(() => _team = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).changeFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _shareCodeLoading = false);
    }
  }

  Future<void> _regenerateShareCode() async {
    setState(() => _shareCodeLoading = true);
    try {
      await ref.read(supabaseServiceProvider)
          .generateTeamShareCode(widget.teamId);
      final updated = await ref.read(supabaseServiceProvider).getTeam(widget.teamId);
      if (mounted) {
        setState(() => _team = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).shareCodeRegenerated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).regenFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _shareCodeLoading = false);
    }
  }

  Future<void> _showInviteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => InviteMemberDialog(
        teamId: widget.teamId,
        currentMembers: _members ?? [],
      ),
    );
    if (result == true) {
      await _loadMembers();
      widget.onRefresh();
    }
  }

  String _roleDisplayName(TeamRole role) {
    final l10n = AppLocalizations.of(context);
    switch (role) {
      case TeamRole.owner:
        return l10n.roleOwner;
      case TeamRole.member:
        return l10n.roleMember;
      case TeamRole.observer:
        return l10n.roleObserver;
    }
  }

  Future<void> _onMemberAction(String action, TeamMember member) async {
    final service = ref.read(supabaseServiceProvider);

    switch (action) {
      case 'promote_member':
        await service.updateMemberRole(
            widget.teamId, member.id, TeamRole.member);
        await _loadMembers();
        widget.onRefresh();
        break;

      case 'demote_observer':
        await service.updateMemberRole(
            widget.teamId, member.id, TeamRole.observer);
        await _loadMembers();
        widget.onRefresh();
        break;

      case 'transfer_owner':
        _showTransferOwnershipDialog(member);
        break;

      case 'kick':
        final l10nKick = AppLocalizations.of(context);
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10nKick.kickMemberTitle),
            content:
            Text(l10nKick.kickMemberConfirm(member.userName ?? l10nKick.thisMember)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10nKick.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10nKick.kick),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await service.leaveTeam(widget.teamId, member.userId);
          await _loadMembers();
        }
        break;
    }
  }

  void _showTransferOwnershipDialog(TeamMember member) {
    final l10n = AppLocalizations.of(context);
    // 1차 확인
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.transferOwnership),
        content: Text(l10n.transferOwnershipContent(member.userName ?? l10n.thisMember)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 2차 확인
              _showTransferOwnershipConfirmDialog(member);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(l10n.transferProceed),
          ),
        ],
      ),
    );
  }

  void _showTransferOwnershipConfirmDialog(TeamMember member) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.finalConfirm),
        content: Text(l10n.finalTransferConfirm(member.userName ?? l10n.thisMember)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final service = ref.read(supabaseServiceProvider);
              final currentUserId = service.currentUser?.id;
              if (currentUserId == null) return;

              try {
                await service.transferOwnership(
                  widget.teamId,
                  currentUserId,
                  member.userId,
                );
                await _loadMembers();
                widget.onRefresh();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).transferSuccess)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).transferFailed(e.toString()))),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.finalTransferBtn),
          ),
        ],
      ),
    );
  }
}

// ──────────────── CRM Tab ────────────────

class _CrmTab extends ConsumerStatefulWidget {
  final String teamId;
  final TeamRole? myRole;

  const _CrmTab({required this.teamId, this.myRole});

  @override
  ConsumerState<_CrmTab> createState() => _CrmTabState();
}

class _CrmTabState extends ConsumerState<_CrmTab> {
  List<CrmContact> _contacts = [];
  Map<CrmStatus, int> _stats = {};
  bool _loading = true;
  bool _tableNotFound = false;
  CrmStatus? _filterStatus;
  String _searchQuery = '';
  bool _showPipeline = true;

  bool get _isObserver => widget.myRole == TeamRole.observer;

  void _showNoPermission() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).noPermissionObserver)),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final contacts = await service.getCrmContacts(widget.teamId, status: _filterStatus);
      final stats = await service.getCrmPipelineStats(widget.teamId);
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _stats = stats;
          _loading = false;
          _tableNotFound = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('PGRST205') || e.toString().contains('could not find')) {
        if (mounted) {
          setState(() {
            _loading = false;
            _tableNotFound = true;
          });
        }
      } else {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).loadFailed(e.toString()))),
          );
        }
      }
    }
  }

  List<CrmContact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    final q = _searchQuery.toLowerCase();
    return _contacts.where((c) {
      return (c.name?.toLowerCase().contains(q) ?? false) ||
          (c.company?.toLowerCase().contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false) ||
          (c.position?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tableNotFound) {
      return _buildSetupScreen(theme, l10n);
    }

    return Column(
      children: [
        // Pipeline summary
        if (_showPipeline) _buildPipelineSummary(theme, l10n),

        // Search & filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _showPipeline ? Icons.view_kanban : Icons.view_kanban_outlined,
                  size: 22,
                ),
                onPressed: () => setState(() => _showPipeline = !_showPipeline),
                tooltip: l10n.pipelineView,
              ),
            ],
          ),
        ),

        // Status filter chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip(null, l10n.allCategories, theme),
              ...CrmStatus.values.map((s) => _buildFilterChip(s, s.label, theme)),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Contact list
        Expanded(
          child: _filteredContacts.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.contact_phone_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noContacts,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.addContactHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: _filteredContacts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final contact = _filteredContacts[index];
                return _CrmContactCard(
                  contact: contact,
                  onTap: () => _showContactDetail(contact),
                  onStatusChanged: (status) async {
                    if (_isObserver) {
                      _showNoPermission();
                      return;
                    }
                    // 즉시 UI 반영 (낙관적 업데이트)
                    setState(() {
                      final idx = _contacts.indexWhere((c) => c.id == contact.id);
                      if (idx != -1) {
                        _contacts[idx] = _contacts[idx].copyWith(status: status);
                        // 통계 업데이트
                        _stats[contact.status] = (_stats[contact.status] ?? 1) - 1;
                        _stats[status] = (_stats[status] ?? 0) + 1;
                      }
                    });
                    await ref.read(supabaseServiceProvider)
                        .updateCrmContactStatus(contact.id, status);
                  },
                );
              },
            ),
          ),
        ),

        // Bottom actions
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (_isObserver) {
                        _showNoPermission();
                        return;
                      }
                      _showImportFromSharedCards();
                    },
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(l10n.importFromSharedCards),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_isObserver) {
                        _showNoPermission();
                        return;
                      }
                      _showAddContactDialog();
                    },
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: Text(l10n.addManually),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineSummary(ThemeData theme, AppLocalizations l10n) {
    final total = _stats.values.fold<int>(0, (a, b) => a + b);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.5),
            theme.colorScheme.secondaryContainer.withOpacity(0.3),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.pipeline,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                l10n.totalPeople(total),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Pipeline bar
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: CrmStatus.values.where((s) => (_stats[s] ?? 0) > 0).map((s) {
                    final count = _stats[s] ?? 0;
                    return Expanded(
                      flex: count,
                      child: Container(color: _statusColor(s)),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (total > 0) const SizedBox(height: 10),
          // Status counts row
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: CrmStatus.values.map((s) {
              final count = _stats[s] ?? 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _statusColor(s),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${s.label} $count',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(CrmStatus? status, String label, ThemeData theme) {
    final selected = _filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) {
          setState(() => _filterStatus = status);
          _loadData();
        },
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSetupScreen(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 48,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.crmSetupRequired,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.crmSetupInstruction,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(CrmStatus status) {
    switch (status) {
      case CrmStatus.lead:
        return Colors.grey;
      case CrmStatus.contact:
        return Colors.blue;
      case CrmStatus.meeting:
        return Colors.orange;
      case CrmStatus.proposal:
        return Colors.purple;
      case CrmStatus.contract:
        return Colors.teal;
      case CrmStatus.closed:
        return Colors.green;
    }
  }

  void _showContactDetail(CrmContact contact) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CrmContactDetailScreen(
          contact: contact,
          teamId: widget.teamId,
          myRole: widget.myRole,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final positionCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final memoCtrl = TextEditingController();

    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.addCrmContact, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _buildTextField(nameCtrl, l10n.name, Icons.person_outline),
              _buildTextField(companyCtrl, l10n.company, Icons.business_outlined),
              _buildTextField(positionCtrl, l10n.jobTitle, Icons.badge_outlined),
              _buildTextField(emailCtrl, l10n.email, Icons.email_outlined),
              _buildTextField(phoneCtrl, l10n.phoneNumber, Icons.phone_outlined),
              _buildTextField(memoCtrl, l10n.memo, Icons.note_outlined, maxLines: 3),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final service = ref.read(supabaseServiceProvider);
                    final userId = service.currentUser?.id;
                    if (userId == null) return;

                    final contact = CrmContact(
                      id: '',
                      teamId: widget.teamId,
                      createdBy: userId,
                      name: nameCtrl.text.isEmpty ? null : nameCtrl.text,
                      company: companyCtrl.text.isEmpty ? null : companyCtrl.text,
                      position: positionCtrl.text.isEmpty ? null : positionCtrl.text,
                      email: emailCtrl.text.isEmpty ? null : emailCtrl.text,
                      phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                      memo: memoCtrl.text.isEmpty ? null : memoCtrl.text,
                      status: CrmStatus.lead,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    await service.createCrmContact(contact);
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context).contactAdded)),
                      );
                    }
                  },
                  child: Text(l10n.add),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  void _showImportFromSharedCards() async {
    final service = ref.read(supabaseServiceProvider);
    final sharedCards = await service.getTeamSharedCards(widget.teamId);
    if (!mounted) return;

    // Filter out cards already imported
    final existingCardIds = _contacts
        .where((c) => c.sharedCardId != null)
        .map((c) => c.sharedCardId)
        .toSet();

    final availableCards = sharedCards
        .where((c) => !existingCardIds.contains(c['id']))
        .toList();

    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    l10n.importFromSharedCards,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (availableCards.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        for (final card in availableCards) {
                          await service.importSharedCardToCrm(card, widget.teamId);
                        }
                        await _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context).importedContacts(availableCards.length))),
                          );
                        }
                      },
                      child: Text(l10n.importAll),
                    ),
                ],
              ),
            ),
            if (availableCards.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.noNewCards,
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: availableCards.length,
                  itemBuilder: (_, index) {
                    final card = availableCards[index];
                    final name = card['name'] as String? ?? l10n.noName;
                    final company = card['company'] as String?;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(name.isNotEmpty ? name[0] : '?'),
                      ),
                      title: Text(name),
                      subtitle: Text(company ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await service.importSharedCardToCrm(card, widget.teamId);
                          await _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(context).contactAddedFromCard(name))),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ──────────────── CRM Contact Card ────────────────

class _CrmContactCard extends StatelessWidget {
  final CrmContact contact;
  final VoidCallback onTap;
  final ValueChanged<CrmStatus> onStatusChanged;

  const _CrmContactCard({
    required this.contact,
    required this.onTap,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = (contact.name?.isNotEmpty == true) ? contact.name![0] : '?';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _statusColor(contact.status).withOpacity(0.15),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _statusColor(contact.status),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name ?? AppLocalizations.of(context).noName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (contact.company != null || contact.position != null)
                      Text(
                        [contact.company, contact.position]
                            .where((s) => s != null)
                            .join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<CrmStatus>(
                initialValue: contact.status,
                onSelected: onStatusChanged,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(contact.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    contact.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(contact.status),
                    ),
                  ),
                ),
                itemBuilder: (_) => CrmStatus.values.map((s) {
                  return PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _statusColor(s),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(s.label),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(CrmStatus status) {
    switch (status) {
      case CrmStatus.lead:
        return Colors.grey;
      case CrmStatus.contact:
        return Colors.blue;
      case CrmStatus.meeting:
        return Colors.orange;
      case CrmStatus.proposal:
        return Colors.purple;
      case CrmStatus.contract:
        return Colors.teal;
      case CrmStatus.closed:
        return Colors.green;
    }
  }
}

// ──────────────── CRM Contact Detail Screen ────────────────

class _CrmContactDetailScreen extends ConsumerStatefulWidget {
  final CrmContact contact;
  final String teamId;
  final TeamRole? myRole;

  const _CrmContactDetailScreen({
    required this.contact,
    required this.teamId,
    this.myRole,
  });

  @override
  ConsumerState<_CrmContactDetailScreen> createState() =>
      _CrmContactDetailScreenState();
}

class _CrmContactDetailScreenState
    extends ConsumerState<_CrmContactDetailScreen> {
  late CrmContact _contact;
  List<CrmNote> _notes = [];
  bool _loadingNotes = true;
  final _noteController = TextEditingController();
  bool _isEditing = false;

  bool get _isObserver => widget.myRole == TeamRole.observer;

  void _showNoPermission() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).noPermissionObserver)),
    );
  }

  // Edit controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _positionCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _memoCtrl;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
    _initEditControllers();
    _loadNotes();
  }

  void _initEditControllers() {
    _nameCtrl = TextEditingController(text: _contact.name ?? '');
    _companyCtrl = TextEditingController(text: _contact.company ?? '');
    _positionCtrl = TextEditingController(text: _contact.position ?? '');
    _deptCtrl = TextEditingController(text: _contact.department ?? '');
    _emailCtrl = TextEditingController(text: _contact.email ?? '');
    _phoneCtrl = TextEditingController(text: _contact.phone ?? '');
    _mobileCtrl = TextEditingController(text: _contact.mobile ?? '');
    _memoCtrl = TextEditingController(text: _contact.memo ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _positionCtrl.dispose();
    _deptCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _mobileCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _loadingNotes = true);
    final notes = await ref
        .read(supabaseServiceProvider)
        .getCrmNotes(_contact.id);
    if (mounted) {
      setState(() {
        _notes = notes;
        _loadingNotes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_contact.name ?? AppLocalizations.of(context).crmContact),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () {
                if (_isObserver) {
                  _showNoPermission();
                  return;
                }
                setState(() => _isEditing = true);
              },
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check, size: 22),
              onPressed: _saveContact,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') {
                if (_isObserver) {
                  _showNoPermission();
                  return;
                }
                _deleteContact();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Text(AppLocalizations.of(context).delete, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status selector
            _buildStatusSelector(theme),
            const SizedBox(height: 16),

            // Contact info
            if (_isEditing) _buildEditForm(theme) else _buildInfoSection(theme),

            const SizedBox(height: 20),

            // Quick actions
            if (!_isEditing) _buildQuickActions(theme),

            if (!_isEditing) const SizedBox(height: 20),

            // Notes section
            if (!_isEditing) _buildNotesSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).status,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: CrmStatus.values.map((s) {
                final selected = _contact.status == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s.label, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (_) {
                      if (_isObserver) {
                        _showNoPermission();
                        return;
                      }
                      _updateStatus(s);
                    },
                    visualDensity: VisualDensity.compact,
                    selectedColor: _statusColor(s).withOpacity(0.2),
                    side: BorderSide(
                      color: selected ? _statusColor(s) : theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final fields = <MapEntry<String, String?>>[];
    if (_contact.name != null) fields.add(MapEntry(l10n.name, _contact.name));
    if (_contact.company != null) fields.add(MapEntry(l10n.company, _contact.company));
    if (_contact.position != null) fields.add(MapEntry(l10n.jobTitle, _contact.position));
    if (_contact.department != null) fields.add(MapEntry(l10n.department, _contact.department));
    if (_contact.email != null) fields.add(MapEntry(l10n.email, _contact.email));
    if (_contact.phone != null) fields.add(MapEntry(l10n.phone, _contact.phone));
    if (_contact.mobile != null) fields.add(MapEntry(l10n.mobileNumber, _contact.mobile));
    if (_contact.memo != null) fields.add(MapEntry(l10n.memo, _contact.memo));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.contactInfo,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (fields.isEmpty)
            Text(
              l10n.noInfo,
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4)),
            )
          else
            ...fields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      f.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.value ?? '',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildEditForm(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.editInfo,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _editField(_nameCtrl, l10n.name),
          _editField(_companyCtrl, l10n.company),
          _editField(_positionCtrl, l10n.jobTitle),
          _editField(_deptCtrl, l10n.department),
          _editField(_emailCtrl, l10n.email),
          _editField(_phoneCtrl, l10n.phone),
          _editField(_mobileCtrl, l10n.mobileNumber),
          _editField(_memoCtrl, l10n.memo, maxLines: 3),
        ],
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_contact.phone != null)
          ActionChip(
            avatar: const Icon(Icons.phone, size: 16),
            label: Text(l10n.phone),
            onPressed: () => _launchUrl('tel:${_contact.phone}'),
          ),
        if (_contact.mobile != null)
          ActionChip(
            avatar: const Icon(Icons.smartphone, size: 16),
            label: Text(l10n.mobileNumber),
            onPressed: () => _launchUrl('tel:${_contact.mobile}'),
          ),
        if (_contact.email != null)
          ActionChip(
            avatar: const Icon(Icons.email, size: 16),
            label: Text(l10n.email),
            onPressed: () => _launchUrl('mailto:${_contact.email}'),
          ),
      ],
    );
  }

  Widget _buildNotesSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notes, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              l10n.activityNotes,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              l10n.noteCount(_notes.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Add note field
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _noteController,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: l10n.noteHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () {
                if (_isObserver) {
                  _showNoPermission();
                  return;
                }
                _addNote();
              },
              icon: const Icon(Icons.send, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Notes list
        if (_loadingNotes)
          const Center(child: CircularProgressIndicator())
        else if (_notes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.noNotes,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),
          )
        else
          ...(_notes.map((note) => _buildNoteCard(note, theme))),
      ],
    );
  }

  Widget _buildNoteCard(CrmNote note, ThemeData theme) {
    final service = ref.read(supabaseServiceProvider);
    final isAuthor = service.currentUser?.id == note.authorId;
    final dateStr = _formatDate(note.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  (note.authorName ?? '?')[0],
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                note.authorName ?? AppLocalizations.of(context).unknown,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (isAuthor)
                InkWell(
                  onTap: () async {
                    await ref.read(supabaseServiceProvider).deleteCrmNote(note.id);
                    await _loadNotes();
                  },
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(note.content, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${date.month}/${date.day}';
  }

  Color _statusColor(CrmStatus status) {
    switch (status) {
      case CrmStatus.lead:
        return Colors.grey;
      case CrmStatus.contact:
        return Colors.blue;
      case CrmStatus.meeting:
        return Colors.orange;
      case CrmStatus.proposal:
        return Colors.purple;
      case CrmStatus.contract:
        return Colors.teal;
      case CrmStatus.closed:
        return Colors.green;
    }
  }

  Future<void> _updateStatus(CrmStatus status) async {
    await ref.read(supabaseServiceProvider)
        .updateCrmContactStatus(_contact.id, status);
    setState(() => _contact = _contact.copyWith(status: status));
  }

  Future<void> _saveContact() async {
    final updated = _contact.copyWith(
      name: _nameCtrl.text.isEmpty ? null : _nameCtrl.text,
      company: _companyCtrl.text.isEmpty ? null : _companyCtrl.text,
      position: _positionCtrl.text.isEmpty ? null : _positionCtrl.text,
      department: _deptCtrl.text.isEmpty ? null : _deptCtrl.text,
      email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text,
      phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
      mobile: _mobileCtrl.text.isEmpty ? null : _mobileCtrl.text,
      memo: _memoCtrl.text.isEmpty ? null : _memoCtrl.text,
      updatedAt: DateTime.now(),
    );

    final result = await ref.read(supabaseServiceProvider).updateCrmContact(updated);
    setState(() {
      _contact = result;
      _isEditing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saved)),
      );
    }
  }

  Future<void> _addNote() async {
    final content = _noteController.text.trim();
    if (content.isEmpty) return;

    final service = ref.read(supabaseServiceProvider);
    final userId = service.currentUser?.id;
    if (userId == null) return;

    final profile = await service.getUserProfile(userId);

    final note = CrmNote(
      id: '',
      contactId: _contact.id,
      authorId: userId,
      authorName: profile?.name,
      content: content,
      createdAt: DateTime.now(),
    );

    await service.addCrmNote(note);
    _noteController.clear();
    await _loadNotes();
  }

  Future<void> _deleteContact() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteContact),
        content: Text(l10n.deleteContactConfirm(_contact.name ?? l10n.thisContact)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(supabaseServiceProvider).deleteCrmContact(_contact.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

// ──────────────── Share Code Section Widget ────────────────

class _ShareCodeSection extends StatelessWidget {
  final Team team;
  final bool isOwner;
  final bool isLoading;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRegenerate;

  const _ShareCodeSection({
    required this.team,
    required this.isOwner,
    required this.isLoading,
    required this.onToggle,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final enabled = team.shareCodeEnabled;
    final code = team.shareCode;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? theme.colorScheme.primary.withOpacity(0.35)
              : theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.link,
                size: 18,
                color: enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.teamShareCode,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isOwner)
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                isOwner
                    ? l10n.shareCodeEnabledHint
                    : l10n.shareCodeDisabled,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      code != null
                          ? _formatCode(code)
                          : l10n.codeGenerating,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: l10n.copy,
                  onPressed: code == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.shareCodeCopied),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                ),
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: l10n.regenerateCode,
                    onPressed: isLoading ? null : onRegenerate,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.shareCodeObserverNote,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 코드를 4자리씩 구분해서 표시: ABCD-EFGH
  String _formatCode(String code) {
    if (code.length == 8) {
      return '${code.substring(0, 4)}-${code.substring(4)}';
    }
    return code;
  }
}