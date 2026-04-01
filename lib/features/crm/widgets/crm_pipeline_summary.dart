import 'package:flutter/material.dart';
import '../../shared/models/crm_contact.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../utils/crm_helpers.dart';

class CrmPipelineSummary extends StatelessWidget {
  final Map<CrmStatus, int> stats;
  final CrmStatus? filterStatus;
  final ValueChanged<CrmStatus?> onFilterChanged;

  const CrmPipelineSummary({
    super.key,
    required this.stats,
    this.filterStatus,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final total = stats.values.fold<int>(0, (a, b) => a + b);
    final closedCount = stats[CrmStatus.closed] ?? 0;
    final conversionPct = total > 0 ? (closedCount / total * 100).toStringAsFixed(1) : '0.0';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
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
              // 전환율 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${l10n.conversionRate} $conversionPct%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.totalPeople(total),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 파이프라인 단계별 시각화
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: CrmStatus.values.where((s) => (stats[s] ?? 0) > 0).map((s) {
                    final count = stats[s] ?? 0;
                    return Expanded(
                      flex: count,
                      child: Container(
                        color: crmStatusColor(s),
                        alignment: Alignment.center,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (total > 0) const SizedBox(height: 12),
          // 상태별 카운트 (아이콘 + 수치)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: CrmStatus.values.map((s) {
              final count = stats[s] ?? 0;
              final isActive = count > 0;
              return GestureDetector(
                onTap: () => onFilterChanged(filterStatus == s ? null : s),
                child: Column(
                  children: [
                    Icon(
                      crmStatusIcon(s),
                      size: 18,
                      color: isActive
                          ? crmStatusColor(s)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
