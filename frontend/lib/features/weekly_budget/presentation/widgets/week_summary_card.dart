import 'package:flutter/material.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_overview.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';

class WeekSummaryCard extends StatelessWidget {
  final WeeklyWeek weekSummary;
  final bool isCurrentWeek;
  final void Function(WeeklyBudgetItem item)? onItemTap;

  const WeekSummaryCard({
    super.key,
    required this.weekSummary,
    this.isCurrentWeek = false,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalUsage = weekSummary.totalUsageRate;
    final overallColor = _getUsageColor(totalUsage);

    return Card(
      elevation: isCurrentWeek ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentWeek
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${weekSummary.weekNumber}주차',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isCurrentWeek) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '이번 주',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${totalUsage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: overallColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${weekSummary.weekStart} ~ ${weekSummary.weekEnd}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            // Total summary row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryChip(
                    context, '예산', CurrencyFormatter.format(weekSummary.totalBudget)),
                _buildSummaryChip(
                    context, '지출', CurrencyFormatter.format(weekSummary.totalSpent)),
                _buildSummaryChip(context, '잔여',
                    CurrencyFormatter.format(weekSummary.totalRemaining),
                    color: weekSummary.totalRemaining >= 0
                        ? Colors.green
                        : Colors.red),
              ],
            ),
            // Per-item breakdown
            if (weekSummary.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...weekSummary.items.map((item) {
                final progress = (item.usageRate / 100).clamp(0.0, 1.0);
                final itemColor = _getUsageColor(item.usageRate);
                return InkWell(
                  onTap: onItemTap != null && item.categoryId != null
                      ? () => onItemTap!(item)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.folder_outlined,
                                    size: 14,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5)),
                                const SizedBox(width: 4),
                                Text(
                                  item.displayName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (onItemTap != null && item.categoryId != null) ...[
                                  const SizedBox(width: 2),
                                  Icon(Icons.chevron_right, size: 14,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4)),
                                ],
                              ],
                            ),
                            Text(
                              '${CurrencyFormatter.format(item.spentAmount)}원 / ${CurrencyFormatter.format(item.budgetAmount)}원',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: theme.colorScheme.onSurface
                                .withValues(alpha: 0.1),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(itemColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(BuildContext context, String label, String value,
      {Color? color}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value원',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getUsageColor(double usageRate) {
    if (usageRate > 100) return Colors.red;
    if (usageRate > 80) return Colors.orange;
    return Colors.green;
  }
}
