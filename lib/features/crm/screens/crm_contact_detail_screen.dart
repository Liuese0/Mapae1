import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/app_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/models/crm_contact.dart';
import '../../shared/models/team.dart';
import '../utils/crm_helpers.dart';

class CrmContactDetailScreen extends ConsumerStatefulWidget {
  final CrmContact contact;
  final String teamId;
  final TeamRole? myRole;

  const CrmContactDetailScreen({
    super.key,
    required this.contact,
    required this.teamId,
    this.myRole,
  });

  @override
  ConsumerState<CrmContactDetailScreen> createState() =>
      _CrmContactDetailScreenState();
}

class _CrmContactDetailScreenState
    extends ConsumerState<CrmContactDetailScreen>
    with SingleTickerProviderStateMixin {
  late CrmContact _contact;
  List<CrmNote> _notes = [];
  bool _loadingNotes = true;
  final _noteController = TextEditingController();
  bool _isEditing = false;
  late TabController _tabController;
  CrmNoteType _selectedNoteType = CrmNoteType.note;

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
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
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
    final l10n = AppLocalizations.of(context);
    final statusColor = crmStatusColor(_contact.status);
    final initial = (_contact.name?.isNotEmpty == true) ? _contact.name![0] : '?';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_contact.name ?? l10n.crmContact),
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
                child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 헤더 카드: 아바타 + 이름/회사/직책 + 퀵액션
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _contact.name ?? l10n.noName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_contact.company != null || _contact.position != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                [_contact.company, _contact.position]
                                    .where((s) => s != null)
                                    .join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          // 상태 칩
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(crmStatusIcon(_contact.status), size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  crmStatusLabel(_contact.status, l10n),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 퀵 액션 버튼 행
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_contact.phone != null || _contact.mobile != null)
                      _QuickActionButton(
                        icon: Icons.phone,
                        label: l10n.phone,
                        color: Colors.green,
                        onTap: () => _launchUrl('tel:${_contact.mobile ?? _contact.phone}'),
                      ),
                    if (_contact.mobile != null)
                      _QuickActionButton(
                        icon: Icons.message_outlined,
                        label: 'SMS',
                        color: Colors.blue,
                        onTap: () => _launchUrl('sms:${_contact.mobile}'),
                      ),
                    if (_contact.email != null)
                      _QuickActionButton(
                        icon: Icons.email_outlined,
                        label: l10n.email,
                        color: Colors.orange,
                        onTap: () => _launchUrl('mailto:${_contact.email}'),
                      ),
                    _QuickActionButton(
                      icon: Icons.swap_horiz,
                      label: l10n.status,
                      color: theme.colorScheme.primary,
                      onTap: () => _showStatusPicker(),
                    ),
                    _QuickActionButton(
                      icon: Icons.alarm,
                      label: 'Follow-up',
                      color: _contact.followUpDate != null ? Colors.red : Colors.grey,
                      onTap: () => _showFollowUpPicker(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 탭: 정보 / 활동
          if (!_isEditing)
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              indicatorColor: theme.colorScheme.primary,
              tabs: [
                Tab(text: l10n.contactInfo),
                Tab(text: l10n.activityNotes),
              ],
            ),

          // 탭 내용
          Expanded(
            child: _isEditing
                ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildEditForm(theme),
            )
                : TabBarView(
              controller: _tabController,
              children: [
                // 정보 탭
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildInfoSection(theme),
                ),
                // 활동 탭
                _buildActivityTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusPicker() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.status, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CrmStatus.values.map((s) {
                final selected = _contact.status == s;
                return ChoiceChip(
                  avatar: Icon(crmStatusIcon(s), size: 14, color: crmStatusColor(s)),
                  label: Text(crmStatusLabel(s, l10n)),
                  selected: selected,
                  onSelected: (_) {
                    if (_isObserver) {
                      _showNoPermission();
                      return;
                    }
                    Navigator.pop(ctx);
                    _updateStatus(s);
                  },
                  selectedColor: crmStatusColor(s).withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final fields = <_InfoField>[];
    if (_contact.name != null) fields.add(_InfoField(Icons.person_outlined, l10n.name, _contact.name!));
    if (_contact.company != null) fields.add(_InfoField(Icons.business_outlined, l10n.company, _contact.company!));
    if (_contact.position != null) fields.add(_InfoField(Icons.badge_outlined, l10n.jobTitle, _contact.position!));
    if (_contact.department != null) fields.add(_InfoField(Icons.group_outlined, l10n.department, _contact.department!));
    if (_contact.email != null) fields.add(_InfoField(Icons.email_outlined, l10n.email, _contact.email!, onTap: () => _launchUrl('mailto:${_contact.email}')));
    if (_contact.phone != null) fields.add(_InfoField(Icons.phone_outlined, l10n.phone, _contact.phone!, onTap: () => _launchUrl('tel:${_contact.phone}')));
    if (_contact.mobile != null) fields.add(_InfoField(Icons.smartphone_outlined, l10n.mobileNumber, _contact.mobile!, onTap: () => _launchUrl('tel:${_contact.mobile}')));
    if (_contact.memo != null) fields.add(_InfoField(Icons.note_outlined, l10n.memo, _contact.memo!));

    if (fields.isEmpty) {
      return Center(
        child: Text(
          l10n.noInfo,
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
      );
    }

    return Column(
      children: fields.map((f) => _buildInfoRow(f, theme)).toList(),
    );
  }

  Widget _buildInfoRow(_InfoField field, ThemeData theme) {
    return InkWell(
      onTap: field.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(field.icon, size: 20, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                Text(
                  field.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: field.onTap != null ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
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

  Widget _buildActivityTab(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // 노트 입력 + 타입 선택
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // 노트 타입 선택 칩
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final type in [CrmNoteType.note, CrmNoteType.call, CrmNoteType.meeting, CrmNoteType.email])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: Icon(_noteTypeIcon(type), size: 14),
                          label: Text(_noteTypeLabel(type, l10n), style: const TextStyle(fontSize: 11)),
                          selected: _selectedNoteType == type,
                          onSelected: (_) => setState(() => _selectedNoteType = type),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
            ],
          ),
        ),

        // 타임라인
        Expanded(
          child: _loadingNotes
              ? const Center(child: CircularProgressIndicator())
              : _notes.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timeline, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noNotes,
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _notes.length,
            itemBuilder: (context, index) => _buildTimelineCard(_notes[index], theme, index == _notes.length - 1),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard(CrmNote note, ThemeData theme, bool isLast) {
    final service = ref.read(supabaseServiceProvider);
    final isAuthor = service.currentUser?.id == note.authorId;
    final dateStr = _formatDate(note.createdAt);
    final typeColor = _noteTypeColor(note.noteType);
    final typeIcon = _noteTypeIcon(note.noteType);
    final l10n = AppLocalizations.of(context);
    final isSystemNote = note.noteType == CrmNoteType.statusChange;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타임라인 라인 + 아이콘
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, size: 14, color: typeColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 카드 내용
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isSystemNote
                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: isSystemNote
                    ? Border.all(color: typeColor.withValues(alpha: 0.2))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!isSystemNote) ...[
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            (note.authorName ?? '?')[0],
                            style: TextStyle(fontSize: 8, color: theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        isSystemNote ? 'System' : (note.authorName ?? l10n.unknown),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          fontStyle: isSystemNote ? FontStyle.italic : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _noteTypeLabel(note.noteType, l10n),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: typeColor),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                      ),
                      if (isAuthor && !isSystemNote)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: InkWell(
                            onTap: () async {
                              await ref.read(supabaseServiceProvider).deleteCrmNote(note.id);
                              await _loadNotes();
                            },
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: isSystemNote ? FontStyle.italic : null,
                      color: isSystemNote
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _noteTypeIcon(CrmNoteType type) {
    switch (type) {
      case CrmNoteType.note: return Icons.note_outlined;
      case CrmNoteType.call: return Icons.phone_outlined;
      case CrmNoteType.meeting: return Icons.handshake_outlined;
      case CrmNoteType.statusChange: return Icons.swap_horiz;
      case CrmNoteType.email: return Icons.email_outlined;
    }
  }

  Color _noteTypeColor(CrmNoteType type) {
    switch (type) {
      case CrmNoteType.note: return Colors.grey;
      case CrmNoteType.call: return Colors.green;
      case CrmNoteType.meeting: return Colors.orange;
      case CrmNoteType.statusChange: return Colors.purple;
      case CrmNoteType.email: return Colors.blue;
    }
  }

  String _noteTypeLabel(CrmNoteType type, AppLocalizations l10n) {
    switch (type) {
      case CrmNoteType.note: return l10n.memo;
      case CrmNoteType.call: return l10n.phone;
      case CrmNoteType.meeting: return l10n.crmStatusMeeting;
      case CrmNoteType.statusChange: return l10n.status;
      case CrmNoteType.email: return l10n.email;
    }
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

  void _showFollowUpPicker() async {
    if (_isObserver) {
      _showNoPermission();
      return;
    }

    final l10n = AppLocalizations.of(context);

    // 기존 팔로업이 있으면 옵션 바텀시트 먼저 표시
    if (_contact.followUpDate != null) {
      final action = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final date = _contact.followUpDate!;
          final note = _contact.followUpNote;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Follow-up', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.alarm, size: 18, color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Text('${date.year}.${date.month}.${date.day}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(note, style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6))),
                  ),
                ],
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.edit_calendar_outlined),
                  title: Text(l10n.editInfo),
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () => Navigator.pop(ctx, 'edit'),
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  title: Text(l10n.delete, style: TextStyle(color: Colors.red.shade400)),
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );

      if (action == null || !mounted) return;

      if (action == 'delete') {
        final service = ref.read(supabaseServiceProvider);
        await service.clearCrmContactFollowUp(_contact.id);
        setState(() => _contact = CrmContact(
          id: _contact.id,
          teamId: _contact.teamId,
          createdBy: _contact.createdBy,
          name: _contact.name,
          company: _contact.company,
          position: _contact.position,
          department: _contact.department,
          email: _contact.email,
          phone: _contact.phone,
          mobile: _contact.mobile,
          status: _contact.status,
          memo: _contact.memo,
          followUpDate: null,
          followUpNote: null,
          createdAt: _contact.createdAt,
          updatedAt: DateTime.now(),
        ));
        return;
      }
      // action == 'edit' → 아래로 계속 진행
    }

    // 날짜 선택
    final now = DateTime.now();
    final initialDate = _contact.followUpDate ?? now.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked == null || !mounted) return;

    // 팔로업 메모 입력
    final noteCtrl = TextEditingController(text: _contact.followUpNote ?? '');
    final followUpNote = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Follow-up ${picked.month}/${picked.day}'),
        content: TextField(
          controller: noteCtrl,
          decoration: InputDecoration(
            hintText: l10n.memo,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, noteCtrl.text),
            child: Text(l10n.add),
          ),
        ],
      ),
    );

    if (followUpNote == null) return;

    final service = ref.read(supabaseServiceProvider);
    final updated = _contact.copyWith(
      followUpDate: picked,
      followUpNote: followUpNote.isEmpty ? null : followUpNote,
      updatedAt: DateTime.now(),
    );
    await service.updateCrmContact(updated);
    setState(() => _contact = updated);
  }

  Future<void> _updateStatus(CrmStatus status) async {
    final oldStatus = _contact.status;
    await ref.read(supabaseServiceProvider)
        .updateCrmContactStatus(_contact.id, status);
    setState(() => _contact = _contact.copyWith(status: status));

    // 상태 변경 시 자동 시스템 노트 생성
    final l10n = AppLocalizations.of(context);
    final service = ref.read(supabaseServiceProvider);
    final userId = service.currentUser?.id;
    if (userId != null) {
      final profile = await service.getUserProfile(userId);
      final note = CrmNote(
        id: '',
        contactId: _contact.id,
        authorId: userId,
        authorName: profile?.name,
        content: '${crmStatusLabel(oldStatus, l10n)} → ${crmStatusLabel(status, l10n)}',
        noteType: CrmNoteType.statusChange,
        createdAt: DateTime.now(),
      );
      await service.addCrmNote(note);
      await _loadNotes();
    }
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

    final service = ref.read(supabaseServiceProvider);
    final result = await service.updateCrmContact(updated);
    await service.syncCrmToSharedCard(result);
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
      noteType: _selectedNoteType,
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

class _InfoField {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoField(this.icon, this.label, this.value, {this.onTap});
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}