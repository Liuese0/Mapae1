import 'package:flutter/material.dart';
import '../../shared/models/crm_contact.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../utils/crm_helpers.dart';

class CrmContactCard extends StatelessWidget {
  final CrmContact contact;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<CrmStatus> onStatusChanged;
  final bool isSelected;
  final bool selectionMode;

  const CrmContactCard({
    super.key,
    required this.contact,
    required this.onTap,
    this.onLongPress,
    required this.onStatusChanged,
    this.isSelected = false,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final initial = (contact.name?.isNotEmpty == true) ? contact.name![0] : '?';
    final statusColor = crmStatusColor(contact.status);

    return Card(
      elevation: isSelected ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 선택 모드: 체크박스 / 일반 모드: 아바타
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                    size: 24,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name ?? l10n.noName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (contact.company != null || contact.position != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [contact.company, contact.position]
                              .where((s) => s != null)
                              .join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // 팔로업 배지
                    if (contact.followUpDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Icon(
                              Icons.alarm,
                              size: 12,
                              color: contact.followUpDate!.isBefore(DateTime.now())
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${contact.followUpDate!.month}/${contact.followUpDate!.day}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: contact.followUpDate!.isBefore(DateTime.now())
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                            ),
                            if (contact.followUpNote != null) ...[
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  contact.followUpNote!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    // 메모 미리보기
                    if (contact.memo != null && contact.memo!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          contact.memo!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (!selectionMode)
                PopupMenuButton<CrmStatus>(
                  initialValue: contact.status,
                  onSelected: onStatusChanged,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(crmStatusIcon(contact.status), size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          crmStatusLabel(contact.status, l10n),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (_) => CrmStatus.values.map((s) {
                    return PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Icon(crmStatusIcon(s), size: 16, color: crmStatusColor(s)),
                          const SizedBox(width: 8),
                          Text(crmStatusLabel(s, l10n)),
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
}
