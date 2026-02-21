import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/models/app_user.dart';
import '../../shared/models/team.dart';

class InviteMemberDialog extends ConsumerStatefulWidget {
  final String teamId;
  final List<TeamMember> currentMembers;

  const InviteMemberDialog({
    super.key,
    required this.teamId,
    required this.currentMembers,
  });

  @override
  ConsumerState<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<InviteMemberDialog> {
  final _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  bool _searching = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchUsers(query.trim());
    });
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _searching = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(supabaseServiceProvider);
      final currentUserId = service.currentUser?.id;
      final results = await service.searchUsersByEmail(query);

      // 자기 자신과 이미 멤버인 유저는 제외
      final memberIds = widget.currentMembers.map((m) => m.userId).toSet();
      final filtered = results
          .where((u) => u.id != currentUserId && !memberIds.contains(u.id))
          .toList();

      // 검색 결과는 있지만 필터링으로 제외된 경우 안내 메시지 표시
      String? filterMessage;
      if (results.isNotEmpty && filtered.isEmpty) {
        final l10n = AppLocalizations.of(context);
        final hasCurrentUser = results.any((u) => u.id == currentUserId);
        final hasExistingMember = results.any((u) => memberIds.contains(u.id));
        if (hasCurrentUser && results.length == 1) {
          filterMessage = l10n.cannotInviteSelf;
        } else if (hasExistingMember) {
          filterMessage = l10n.alreadyTeamMember;
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = filtered;
          _searching = false;
          _errorMessage = filterMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _errorMessage = AppLocalizations.of(context).searchError;
        });
      }
    }
  }

  Future<void> _sendInvitation(AppUser user) async {
    final l10n = AppLocalizations.of(context);
    try {
      final service = ref.read(supabaseServiceProvider);

      // 이미 보낸 초대가 있는지 확인
      final pending = await service.getTeamPendingInvitations(widget.teamId);
      final alreadyInvited = pending.any((inv) => inv.inviteeId == user.id);
      if (alreadyInvited) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.alreadyInvited)),
          );
        }
        return;
      }

      await service.sendTeamInvitation(
        teamId: widget.teamId,
        inviteeId: user.id,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inviteSent(user.name ?? user.email ?? ''))),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nCurrent = AppLocalizations.of(context);
        final message = e.toString().contains('duplicate key') ||
            e.toString().contains('23505')
            ? l10nCurrent.alreadyInvited
            : l10nCurrent.inviteError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.inviteMember,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.inviteMemberHint,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.emailAddressHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searching
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _errorMessage = null;
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: _buildSearchResults(theme),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    final l10n = AppLocalizations.of(context);

    if (_searchController.text.trim().length < 2) {
      return const SizedBox.shrink();
    }

    if (_searching) {
      return const SizedBox.shrink();
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            l10n.noSearchResults,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            backgroundImage:
            user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Icon(Icons.person, color: theme.colorScheme.primary)
                : null,
          ),
          title: Text(
            user.name ?? l10n.noName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            user.email ?? '',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          trailing: OutlinedButton(
            onPressed: () => _showInviteConfirm(user),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
            child: Text(l10n.invite),
          ),
        );
      },
    );
  }

  void _showInviteConfirm(AppUser user) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inviteConfirmTitle),
        content: Text(l10n.inviteConfirmMessage(user.name ?? user.email ?? '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendInvitation(user);
            },
            child: Text(l10n.invite),
          ),
        ],
      ),
    );
  }
}
