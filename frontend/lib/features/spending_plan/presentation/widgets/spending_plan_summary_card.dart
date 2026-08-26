import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';
import '../../../../core/theme/bb_scale.dart';

class SpendingPlanSummaryCard extends StatelessWidget {
  final SpendingPlanSummary summary;

  const SpendingPlanSummaryCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCount = summary.totalCount;
    final progress =
        totalCount > 0 ? summary.completedCount / totalCount : 0.0;

    return Card(
      // ★세로는 블록 축(`gapV(block)`)이 갖는다 — 가로만 남긴다.
      margin: EdgeInsets.symmetric(horizontal: context.bbSpace.xl),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: total planned vs completed
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '계획 금액',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      context.bbSpace.gapV(BbSpaceToken.xs),
                      Text(
                        '${CurrencyFormatter.format(summary.totalPlanned)}원',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '완료 금액',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      context.bbSpace.gapV(BbSpaceToken.xs),
                      Text(
                        '${CurrencyFormatter.format(summary.totalCompleted)}원',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                color: Colors.green,
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),
            // Status badges row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatusBadge(
                  label: '계획',
                  count: summary.plannedCount,
                  color: Colors.blue,
                ),
                _StatusBadge(
                  label: '완료',
                  count: summary.completedCount,
                  color: Colors.green,
                ),
                _StatusBadge(
                  label: '건너뜀',
                  count: summary.totalSkipped > 0
                      ? summary.totalSkipped
                      : 0,
                  color: Colors.grey,
                  // Use count from skipped total for display
                  useAmount: false,
                ),
                _StatusBadge(
                  label: '기한초과',
                  count: summary.overdueCount,
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool useAmount;

  const _StatusBadge({
    required this.label,
    required this.count,
    required this.color,
    this.useAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        context.bbSpace.gapV(BbSpaceToken.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
