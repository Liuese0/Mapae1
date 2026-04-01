import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/models/crm_contact.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../utils/crm_helpers.dart';

class CrmKanbanBoard extends StatelessWidget {
  final List<CrmContact> contacts;
  final ValueChanged<CrmContact> onContactTap;
  final void Function(CrmContact contact, CrmStatus newStatus) onStatusChanged;

  const CrmKanbanBoard({
    super.key,
    required this.contacts,
    required this.onContactTap,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: CrmStatus.values.map((status) {
        final columnContacts = contacts.where((c) => c.status == status).toList();
        return _KanbanColumn(
          status: status,
          contacts: columnContacts,
          theme: theme,
          l10n: l10n,
          onContactTap: onContactTap,
          onStatusChanged: onStatusChanged,
        );
      }).toList(),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final CrmStatus status;
  final List<CrmContact> contacts;
  final ThemeData theme;
  final AppLocalizations l10n;
  final ValueChanged<CrmContact> onContactTap;
  final void Function(CrmContact contact, CrmStatus newStatus) onStatusChanged;

  const _KanbanColumn({
    required this.status,
    required this.contacts,
    required this.theme,
    required this.l10n,
    required this.onContactTap,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = crmStatusColor(status);
    final screenWidth = MediaQuery.of(context).size.width;
    final columnWidth = (screenWidth * 0.72).clamp(240.0, 320.0);

    return DragTarget<CrmContact>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        HapticFeedback.mediumImpact();
        onStatusChanged(details.data, status);
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: columnWidth,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isHighlighted
                ? color.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted
                  ? color.withValues(alpha: 0.5)
                  : theme.colorScheme.outline.withValues(alpha: 0.15),
              width: isHighlighted ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // 컬럼 헤더
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(crmStatusIcon(status), size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      crmStatusLabel(status, l10n),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${contacts.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 카드 리스트
              Expanded(
                child: contacts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l10n.noContacts,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          return _KanbanCard(
                            contact: contact,
                            color: color,
                            theme: theme,
                            l10n: l10n,
                            onTap: () => onContactTap(contact),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KanbanCard extends StatelessWidget {
  final CrmContact contact;
  final Color color;
  final ThemeData theme;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _KanbanCard({
    required this.contact,
    required this.color,
    required this.theme,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (contact.name?.isNotEmpty == true) ? contact.name![0] : '?';

    return Draggable<CrmContact>(
      data: contact,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  contact.name ?? l10n.noName,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCardContent(initial),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: _buildCardContent(initial),
      ),
    );
  }

  Widget _buildCardContent(String initial) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  contact.name ?? l10n.noName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (contact.company != null) ...[
            const SizedBox(height: 4),
            Text(
              contact.company!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (contact.memo != null && contact.memo!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              contact.memo!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (contact.followUpDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.alarm,
                  size: 11,
                  color: contact.followUpDate!.isBefore(DateTime.now())
                      ? Colors.red
                      : Colors.orange,
                ),
                const SizedBox(width: 3),
                Text(
                  '${contact.followUpDate!.month}/${contact.followUpDate!.day}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: contact.followUpDate!.isBefore(DateTime.now())
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
