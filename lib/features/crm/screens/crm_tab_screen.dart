import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/models/crm_contact.dart';
import '../../shared/models/team.dart';
import '../utils/crm_helpers.dart';
import '../widgets/crm_contact_card.dart';
import '../widgets/crm_pipeline_summary.dart';
import '../widgets/crm_kanban_board.dart';
import '../widgets/crm_dashboard.dart';
import 'crm_contact_detail_screen.dart';

enum CrmViewMode { list, kanban }
enum _FollowUpFilter { all, overdue, thisWeek, hasFollowUp }

class CrmTab extends ConsumerStatefulWidget {
  final String teamId;
  final TeamRole? myRole;

  const CrmTab({super.key, required this.teamId, this.myRole});

  @override
  ConsumerState<CrmTab> createState() => _CrmTabState();
}

class _CrmTabState extends ConsumerState<CrmTab> {
  List<CrmContact> _contacts = [];
  Map<CrmStatus, int> _stats = {};
  bool _loading = true;
  bool _tableNotFound = false;
  CrmStatus? _filterStatus;
  String _searchQuery = '';
  CrmViewMode _viewMode = CrmViewMode.list;
  bool _showPipeline = true;

  // 고급 필터
  String? _filterCompany;
  _FollowUpFilter _followUpFilter = _FollowUpFilter.all;

  // 정렬
  CrmSortMode _sortMode = CrmSortMode.recent;

  // 다중 선택
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  // 검색 디바운스
  Timer? _searchDebounce;
  final _searchController = TextEditingController();

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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
    var list = _contacts.toList();

    // 검색 필터
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        return (c.name?.toLowerCase().contains(q) ?? false) ||
            (c.company?.toLowerCase().contains(q) ?? false) ||
            (c.email?.toLowerCase().contains(q) ?? false) ||
            (c.position?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // 회사별 필터
    if (_filterCompany != null) {
      list = list.where((c) => c.company == _filterCompany).toList();
    }

    // 팔로업 필터
    final now = DateTime.now();
    switch (_followUpFilter) {
      case _FollowUpFilter.all:
        break;
      case _FollowUpFilter.overdue:
        list = list.where((c) =>
        c.followUpDate != null && c.followUpDate!.isBefore(now)).toList();
        break;
      case _FollowUpFilter.thisWeek:
        final weekLater = now.add(const Duration(days: 7));
        list = list.where((c) =>
        c.followUpDate != null &&
            !c.followUpDate!.isBefore(now) &&
            c.followUpDate!.isBefore(weekLater)).toList();
        break;
      case _FollowUpFilter.hasFollowUp:
        list = list.where((c) => c.followUpDate != null).toList();
        break;
    }

    // 정렬
    switch (_sortMode) {
      case CrmSortMode.recent:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case CrmSortMode.name:
        list.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
        break;
      case CrmSortMode.status:
        list.sort((a, b) => a.status.index.compareTo(b.status.index));
        break;
    }

    return list;
  }

  List<String> get _distinctCompanies {
    return _contacts
        .map((c) => c.company)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _handleExportCrm() async {
    final l10n = AppLocalizations.of(context);
    final contacts = _selectionMode
        ? _filteredContacts.where((c) => _selectedIds.contains(c.id)).toList()
        : _filteredContacts;
    if (contacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noDataToExport)),
        );
      }
      return;
    }
    try {
      await ExcelExportService.exportCrmContacts(contacts);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.excelExportFailed)),
        );
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_filteredContacts.map((c) => c.id));
    });
  }

  Future<void> _batchChangeStatus(CrmStatus newStatus) async {
    if (_isObserver) { _showNoPermission(); return; }
    final service = ref.read(supabaseServiceProvider);
    final ids = _selectedIds.toList();

    // 낙관적 업데이트
    setState(() {
      for (final id in ids) {
        final idx = _contacts.indexWhere((c) => c.id == id);
        if (idx != -1) {
          final old = _contacts[idx];
          _stats[old.status] = (_stats[old.status] ?? 1) - 1;
          _stats[newStatus] = (_stats[newStatus] ?? 0) + 1;
          _contacts[idx] = old.copyWith(status: newStatus);
        }
      }
    });

    for (final id in ids) {
      await service.updateCrmContactStatus(id, newStatus);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).batchStatusChanged(ids.length))),
      );
    }
    _exitSelectionMode();
  }

  Future<void> _batchDelete() async {
    if (_isObserver) { _showNoPermission(); return; }
    final l10n = AppLocalizations.of(context);
    final count = _selectedIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.batchDelete),
        content: Text(l10n.confirmBatchDelete(count)),
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

    if (confirm != true) return;

    final service = ref.read(supabaseServiceProvider);
    final ids = _selectedIds.toList();
    for (final id in ids) {
      await service.deleteCrmContact(id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.batchDeleted(count))),
      );
    }
    _exitSelectionMode();
    await _loadData();
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
        // 선택 모드 액션바
        if (_selectionMode) _buildSelectionBar(theme, l10n),

        // Dashboard (리스트 뷰에서만)
        if (_showPipeline && !_selectionMode && _viewMode == CrmViewMode.list)
          CrmDashboard(
            contacts: _contacts,
            stats: _stats,
          ),

        // Search & filter bar
        if (!_selectionMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                          if (mounted) setState(() => _searchQuery = v);
                        });
                      },
                      decoration: InputDecoration(
                        hintText: l10n.searchHint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // 정렬 버튼
                PopupMenuButton<CrmSortMode>(
                  icon: const Icon(Icons.sort, size: 22),
                  tooltip: l10n.sortBy,
                  onSelected: (mode) => setState(() => _sortMode = mode),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: CrmSortMode.recent,
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 18, color: _sortMode == CrmSortMode.recent ? theme.colorScheme.primary : null),
                          const SizedBox(width: 8),
                          Text(l10n.sortByRecent),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: CrmSortMode.name,
                      child: Row(
                        children: [
                          Icon(Icons.sort_by_alpha, size: 18, color: _sortMode == CrmSortMode.name ? theme.colorScheme.primary : null),
                          const SizedBox(width: 8),
                          Text(l10n.sortByName),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: CrmSortMode.status,
                      child: Row(
                        children: [
                          Icon(Icons.linear_scale, size: 18, color: _sortMode == CrmSortMode.status ? theme.colorScheme.primary : null),
                          const SizedBox(width: 8),
                          Text(l10n.sortByStatus),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _viewMode == CrmViewMode.kanban ? Icons.view_list : Icons.view_kanban_outlined,
                    size: 22,
                  ),
                  onPressed: () => setState(() {
                    _viewMode = _viewMode == CrmViewMode.list
                        ? CrmViewMode.kanban
                        : CrmViewMode.list;
                  }),
                  tooltip: _viewMode == CrmViewMode.kanban ? l10n.sortByRecent : l10n.pipelineView,
                ),
                if (_viewMode == CrmViewMode.list)
                  IconButton(
                    icon: Icon(
                      _showPipeline ? Icons.analytics : Icons.analytics_outlined,
                      size: 22,
                    ),
                    onPressed: () => setState(() => _showPipeline = !_showPipeline),
                    tooltip: l10n.pipeline,
                  ),
                IconButton(
                  icon: const Icon(Icons.download_outlined, size: 22),
                  tooltip: l10n.exportToExcel,
                  onPressed: _handleExportCrm,
                ),
              ],
            ),
          ),

        // Status filter chips (리스트 뷰에서만)
        if (!_selectionMode && _viewMode == CrmViewMode.list)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(null, l10n.allCategories, theme),
                ...CrmStatus.values.map((s) => _buildFilterChip(s, crmStatusLabel(s, l10n), theme)),
                const SizedBox(width: 8),
                // 회사 필터
                if (_distinctCompanies.isNotEmpty)
                  PopupMenuButton<String?>(
                    child: Chip(
                      avatar: const Icon(Icons.business_outlined, size: 14),
                      label: Text(
                        _filterCompany ?? l10n.company,
                        style: TextStyle(
                          fontSize: 12,
                          color: _filterCompany != null ? theme.colorScheme.primary : null,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    onSelected: (company) => setState(() => _filterCompany = company),
                    itemBuilder: (_) => [
                      PopupMenuItem<String?>(
                        value: null,
                        child: Text(l10n.allCategories),
                      ),
                      ..._distinctCompanies.map((c) => PopupMenuItem(
                        value: c,
                        child: Text(c),
                      )),
                    ],
                  ),
                const SizedBox(width: 4),
                // 팔로업 필터
                PopupMenuButton<_FollowUpFilter>(
                  child: Chip(
                    avatar: Icon(
                      Icons.alarm,
                      size: 14,
                      color: _followUpFilter != _FollowUpFilter.all ? Colors.orange : null,
                    ),
                    label: Text(
                      _followUpFilterLabel(_followUpFilter),
                      style: TextStyle(
                        fontSize: 12,
                        color: _followUpFilter != _FollowUpFilter.all ? Colors.orange : null,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  onSelected: (filter) => setState(() => _followUpFilter = filter),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: _FollowUpFilter.all, child: Text('All')),
                    const PopupMenuItem(value: _FollowUpFilter.overdue, child: Text('Overdue')),
                    const PopupMenuItem(value: _FollowUpFilter.thisWeek, child: Text('This week')),
                    const PopupMenuItem(value: _FollowUpFilter.hasFollowUp, child: Text('Has follow-up')),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 4),

        // 칸반 뷰
        if (_viewMode == CrmViewMode.kanban && !_selectionMode)
          Expanded(
            child: CrmKanbanBoard(
              contacts: _filteredContacts,
              onContactTap: _showContactDetail,
              onStatusChanged: (contact, newStatus) async {
                setState(() {
                  final idx = _contacts.indexWhere((c) => c.id == contact.id);
                  if (idx != -1) {
                    _contacts[idx] = _contacts[idx].copyWith(status: newStatus);
                    _stats[contact.status] = (_stats[contact.status] ?? 1) - 1;
                    _stats[newStatus] = (_stats[newStatus] ?? 0) + 1;
                  }
                });
                await ref.read(supabaseServiceProvider)
                    .updateCrmContactStatus(contact.id, newStatus);
              },
            ),
          ),

        // Contact list (리스트 뷰에서만)
        if (_viewMode == CrmViewMode.list)
          Expanded(
            child: _filteredContacts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.contact_phone_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noContacts,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.addContactHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
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
                  final isSelected = _selectedIds.contains(contact.id);
                  return CrmContactCard(
                    contact: contact,
                    isSelected: isSelected,
                    selectionMode: _selectionMode,
                    onTap: () {
                      if (_selectionMode) {
                        _toggleSelection(contact.id);
                      } else {
                        _showContactDetail(contact);
                      }
                    },
                    onLongPress: () {
                      if (!_selectionMode) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _selectionMode = true;
                          _selectedIds.add(contact.id);
                        });
                      }
                    },
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

        // Bottom actions (선택 모드가 아닐 때)
        if (!_selectionMode)
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

  /// 선택 모드 액션바
  Widget _buildSelectionBar(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
            ),
            Text(
              l10n.selectedCount(_selectedIds.length),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton(
              onPressed: _selectedIds.length == _filteredContacts.length
                  ? _exitSelectionMode
                  : _selectAll,
              child: Text(
                _selectedIds.length == _filteredContacts.length
                    ? l10n.deselectAll
                    : l10n.selectAll,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            // 일괄 상태 변경
            PopupMenuButton<CrmStatus>(
              icon: Icon(Icons.swap_horiz, color: theme.colorScheme.primary),
              tooltip: l10n.batchStatusChange,
              onSelected: _batchChangeStatus,
              itemBuilder: (_) => CrmStatus.values.map((s) {
                return PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Icon(crmStatusIcon(s), size: 18, color: crmStatusColor(s)),
                      const SizedBox(width: 8),
                      Text(crmStatusLabel(s, l10n)),
                    ],
                  ),
                );
              }).toList(),
            ),
            // 일괄 삭제
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: l10n.batchDelete,
              onPressed: _batchDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _followUpFilterLabel(_FollowUpFilter filter) {
    switch (filter) {
      case _FollowUpFilter.all: return 'Follow-up';
      case _FollowUpFilter.overdue: return 'Overdue';
      case _FollowUpFilter.thisWeek: return 'This week';
      case _FollowUpFilter.hasFollowUp: return 'Scheduled';
    }
  }

  Widget _buildFilterChip(CrmStatus? status, String label, ThemeData theme) {
    final selected = _filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: status != null
            ? Icon(crmStatusIcon(status), size: 14, color: selected ? crmStatusColor(status) : null)
            : null,
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) {
          setState(() => _filterStatus = _filterStatus == status ? null : status);
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
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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

  void _showContactDetail(CrmContact contact) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CrmContactDetailScreen(
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
                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4),
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