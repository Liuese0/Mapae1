import 'package:flutter/material.dart';
import '../../shared/models/crm_contact.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../utils/crm_helpers.dart';

class CrmDashboard extends StatelessWidget {
  final List<CrmContact> contacts;
  final Map<CrmStatus, int> stats;

  const CrmDashboard({
    super.key,
    required this.contacts,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final total = stats.values.fold<int>(0, (a, b) => a + b);
    final closedCount = stats[CrmStatus.closed] ?? 0;
    final conversionPct = total > 0 ? (closedCount / total * 100).toStringAsFixed(1) : '0.0';

    // 이번 주/월 신규
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);
    final thisWeek = contacts.where((c) => c.createdAt.isAfter(weekAgo)).length;
    final thisMonth = contacts.where((c) => c.createdAt.isAfter(monthAgo)).length;

    // 팔로업 통계
    final overdue = contacts.where((c) =>
        c.followUpDate != null && c.followUpDate!.isBefore(now)).length;
    final upcoming = contacts.where((c) =>
        c.followUpDate != null &&
        !c.followUpDate!.isBefore(now) &&
        c.followUpDate!.isBefore(now.add(const Duration(days: 7)))).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 요약 카드들
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _StatCard(
                  icon: Icons.people_outlined,
                  label: l10n.totalPeople(total),
                  value: '$total',
                  color: theme.colorScheme.primary,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  icon: Icons.trending_up,
                  label: l10n.conversionRate,
                  value: '$conversionPct%',
                  color: Colors.green,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  icon: Icons.calendar_today_outlined,
                  label: l10n.crmStatusMeeting,
                  value: '$thisWeek',
                  subtitle: '7d',
                  color: Colors.blue,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  icon: Icons.date_range_outlined,
                  label: l10n.memo,
                  value: '$thisMonth',
                  subtitle: '30d',
                  color: Colors.orange,
                  theme: theme,
                ),
              ],
            ),
          ),

          // 팔로업 알림
          if (overdue > 0 || upcoming > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  if (overdue > 0)
                    _FollowUpBadge(
                      icon: Icons.warning_amber_rounded,
                      label: 'Overdue: $overdue',
                      color: Colors.red,
                      theme: theme,
                    ),
                  if (overdue > 0 && upcoming > 0) const SizedBox(width: 8),
                  if (upcoming > 0)
                    _FollowUpBadge(
                      icon: Icons.alarm,
                      label: 'This week: $upcoming',
                      color: Colors.orange,
                      theme: theme,
                    ),
                ],
              ),
            ),

          // 파이프라인 퍼널 시각화
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 파이프라인 바
                if (total > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: CrmStatus.values
                            .where((s) => (stats[s] ?? 0) > 0)
                            .map((s) {
                          final count = stats[s] ?? 0;
                          return Expanded(
                            flex: count,
                            child: Container(color: crmStatusColor(s)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                if (total > 0) const SizedBox(height: 10),
                // 상태별 카운트 행
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: CrmStatus.values.map((s) {
                    final count = stats[s] ?? 0;
                    final isActive = count > 0;
                    return Column(
                      children: [
                        Icon(
                          crmStatusIcon(s),
                          size: 16,
                          color: isActive
                              ? crmStatusColor(s)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: isActive
                                ? crmStatusColor(s)
                                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        Text(
                          crmStatusLabel(s, l10n),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 9,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final ThemeData theme;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ThemeData theme;

  const _FollowUpBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
