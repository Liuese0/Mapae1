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
      setState(() => _myRole = me?.role);
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
          _SharedCardsTab(teamId: widget.teamId),
          _MembersTab(teamId: widget.teamId),
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

class _SharedCardsTab extends ConsumerWidget {
  final String teamId;

  const _SharedCardsTab({required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return FutureBuilder<List<CollectedCard>>(
      future: ref.read(supabaseServiceProvider).getTeamSharedCards(teamId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final cards = snapshot.data ?? [];
        if (cards.isEmpty) {
          return Center(
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
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final card = cards[index];
            return ListTile(
              title: Text(card.name ?? '이름 없음'),
              subtitle: Text(
                [card.company, card.position]
                    .where((s) => s != null)
                    .join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => context.push('/card/${card.id}'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outline),
              ),
            );
          },
        );
      },
    );
  }
}

class _MembersTab extends ConsumerWidget {
  final String teamId;

  const _MembersTab({required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return FutureBuilder<List<TeamMember>>(
      future: ref.read(supabaseServiceProvider).getTeamMembers(teamId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data ?? [];

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
                        Icons.person,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(member.userName ?? member.userId),
                    subtitle: Text(member.role.name),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.outline),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
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
          ],
        );
      },
    );
  }
}

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