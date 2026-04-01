import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/models/team.dart';
import '../../shared/models/collected_card.dart';
import '../../shared/models/category.dart';
import '../../shared/widgets/invite_member_dialog.dart';
import '../../crm/screens/crm_tab_screen.dart';

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
          CrmTab(teamId: widget.teamId, myRole: _myRole),
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
                onTap: _canShare ? () => _showEditSharedCardSheet(card) : null,
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

  void _showEditSharedCardSheet(Map<String, dynamic> card) {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: card['name'] as String? ?? '');
    final companyCtrl = TextEditingController(text: card['company'] as String? ?? '');
    final positionCtrl = TextEditingController(text: card['position'] as String? ?? '');
    final deptCtrl = TextEditingController(text: card['department'] as String? ?? '');
    final emailCtrl = TextEditingController(text: card['email'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: card['phone'] as String? ?? '');
    final mobileCtrl = TextEditingController(text: card['mobile'] as String? ?? '');
    final memoCtrl = TextEditingController(text: card['memo'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(l10n.edit, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final sharedCardId = card['id'] as String;
                        final fields = <String, dynamic>{
                          'name': nameCtrl.text.isEmpty ? null : nameCtrl.text,
                          'company': companyCtrl.text.isEmpty ? null : companyCtrl.text,
                          'position': positionCtrl.text.isEmpty ? null : positionCtrl.text,
                          'department': deptCtrl.text.isEmpty ? null : deptCtrl.text,
                          'email': emailCtrl.text.isEmpty ? null : emailCtrl.text,
                          'phone': phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                          'mobile': mobileCtrl.text.isEmpty ? null : mobileCtrl.text,
                          'memo': memoCtrl.text.isEmpty ? null : memoCtrl.text,
                        };
                        try {
                          await ref.read(supabaseServiceProvider).updateSharedCard(sharedCardId, fields);
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadCards();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.saved)),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                      child: Text(l10n.save),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: l10n.name)),
                const SizedBox(height: 8),
                TextField(controller: companyCtrl, decoration: InputDecoration(labelText: l10n.company)),
                const SizedBox(height: 8),
                TextField(controller: positionCtrl, decoration: InputDecoration(labelText: l10n.jobTitle)),
                const SizedBox(height: 8),
                TextField(controller: deptCtrl, decoration: InputDecoration(labelText: l10n.department)),
                const SizedBox(height: 8),
                TextField(controller: emailCtrl, decoration: InputDecoration(labelText: l10n.email)),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: l10n.phone)),
                const SizedBox(height: 8),
                TextField(controller: mobileCtrl, decoration: InputDecoration(labelText: l10n.mobileNumber)),
                const SizedBox(height: 8),
                TextField(controller: memoCtrl, decoration: InputDecoration(labelText: l10n.memo), maxLines: 2),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
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

// CRM Tab is now in ../../crm/screens/crm_tab_screen.dart

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