import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../shared/models/team.dart';
import '../../shared/models/collected_card.dart';

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
        title: const Text('팀 관리'),
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
                if (_myRole == TeamRole.owner) {
                  return [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('팀 삭제', style: TextStyle(color: Colors.red)),
                    ),
                  ];
                } else {
                  return [
                    const PopupMenuItem(
                      value: 'leave',
                      child: Text('팀 나가기', style: TextStyle(color: Colors.red)),
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
          tabs: const [
            Tab(text: '공유 명함'),
            Tab(text: '멤버'),
            Tab(text: 'CRM'),
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
          _CrmTab(teamId: widget.teamId),
        ],
      ),
    );
  }

  void _showDeleteTeamDialog(BuildContext context, SupabaseService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('팀 삭제'),
        content: const Text('팀을 삭제하면 모든 멤버와 공유 명함이 삭제됩니다.\n정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              await service.deleteTeam(widget.teamId);
              if (context.mounted) Navigator.pop(context);
              if (this.context.mounted) this.context.go('/management');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showLeaveTeamDialog(
      BuildContext context, SupabaseService service, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('팀 나가기'),
        content: const Text('팀에서 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              await service.leaveTeam(widget.teamId, userId);
              if (context.mounted) Navigator.pop(context);
              if (this.context.mounted) this.context.go('/management');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('나가기'),
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _loading = true);
    final cards = await ref
        .read(supabaseServiceProvider)
        .getTeamSharedCards(widget.teamId);
    if (mounted) {
      setState(() {
        _cards = cards;
        _loading = false;
      });
    }
  }

  bool get _canShare =>
      widget.myRole == TeamRole.owner || widget.myRole == TeamRole.member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final cards = _cards ?? [];

    return Column(
      children: [
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
                  '공유된 명함이 없습니다',
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
              final name = card['name'] as String? ?? '이름 없음';
              final company = card['company'] as String?;
              final position = card['position'] as String?;
              return ListTile(
                title: Text(name),
                subtitle: Text(
                  [company, position]
                      .where((s) => s != null)
                      .join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: '내 지갑으로 복사',
                      onPressed: () => _copyToWallet(card),
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
                  label: const Text('명함 공유하기'),
                ),
              ),
            ),
          ),
      ],
    );
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
            title: const Text('중복 명함'),
            content: const Text('이미 존재하는 명함입니다. 복사하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('복사'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }

      await service.copySharedCardToWallet(card);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('명함이 지갑에 복사되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복사 실패: $e')),
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
          title: const Text('공유할 명함 선택'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: myCards.isEmpty
                ? const Center(child: Text('지갑에 명함이 없습니다'))
                : ListView.builder(
              itemCount: myCards.length,
              itemBuilder: (context, index) {
                final card = myCards[index];
                return ListTile(
                  title: Text(card.name ?? '이름 없음'),
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
                          const SnackBar(
                              content: Text('이미 공유한 명함입니다')),
                        );
                      }
                      return;
                    }
                    Navigator.pop(dialogContext);
                    try {
                      await service.shareCardToTeam(
                          card.id, widget.teamId);
                      await _loadCards();
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                              content: Text('명함이 팀에 공유되었습니다')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('공유 실패: $e')),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final members = await ref
        .read(supabaseServiceProvider)
        .getTeamMembers(widget.teamId);
    if (mounted) {
      setState(() {
        _members = members;
        _loading = false;
      });
    }
  }

  bool get _isOwner => widget.myRole == TeamRole.owner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final members = _members ?? [];

    return Column(
      children: [
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
                    if (member.role == TeamRole.observer) {
                      items.add(const PopupMenuItem(
                        value: 'promote_member',
                        child: Text('멤버로 승격'),
                      ));
                    } else if (member.role == TeamRole.member) {
                      items.add(const PopupMenuItem(
                        value: 'demote_observer',
                        child: Text('관측자로 변경'),
                      ));
                    }
                    items.add(const PopupMenuItem(
                      value: 'transfer_owner',
                      child: Text('Owner 양도'),
                    ));
                    items.add(const PopupMenuItem(
                      value: 'kick',
                      child: Text('팀에서 내보내기',
                          style: TextStyle(color: Colors.red)),
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
                onPressed: () {
                  // TODO: implement invite member
                },
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('멤버 초대'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _roleDisplayName(TeamRole role) {
    switch (role) {
      case TeamRole.owner:
        return 'Owner (주인)';
      case TeamRole.member:
        return 'Member (멤버)';
      case TeamRole.observer:
        return 'Observer (관측자)';
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
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('멤버 내보내기'),
            content:
            Text('${member.userName ?? '이 멤버'}를 팀에서 내보내시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('내보내기'),
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
    // 1차 확인
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Owner 양도'),
        content: Text(
          '${member.userName ?? '이 멤버'}에게 Owner 권한을 양도하시겠습니까?\n'
              '양도 후 본인은 Member로 변경됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 2차 확인
              _showTransferOwnershipConfirmDialog(member);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('양도하기'),
          ),
        ],
      ),
    );
  }

  void _showTransferOwnershipConfirmDialog(TeamMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('최종 확인'),
        content: Text(
          '정말로 ${member.userName ?? '이 멤버'}에게 Owner를 양도하시겠습니까?\n'
              '이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
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
                    const SnackBar(content: Text('Owner가 양도되었습니다')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('양도 실패: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('최종 양도'),
          ),
        ],
      ),
    );
  }
}

// ──────────────── CRM Tab ────────────────

class _CrmTab extends StatelessWidget {
  final String teamId;

  const _CrmTab({required this.teamId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.integration_instructions_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'CRM 연동',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '팀의 명함 데이터를 CRM 시스템과\n연동하여 관리할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: implement CRM connection
              },
              child: const Text('CRM 연동 설정'),
            ),
          ],
        ),
      ),
    );
  }
}