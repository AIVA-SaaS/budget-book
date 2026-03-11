import 'package:flutter/material.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_overview.dart';
import 'package:intl/intl.dart';

class WeekSummaryCard extends StatelessWidget {
  final WeekSummary weekSummary;
  final bool isCurrentWeek;

  const WeekSummaryCard({
    super.key,
    required this.weekSummary,
    this.isCurrentWeek = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');
    final statusColor = _getStatusColor(weekSummary.status);
    final statusLabel = _getStatusLabel(weekSummary.status);
    final progress = (weekSummary.usageRate / 100).clamp(0.0, 1.0);

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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
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
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${numberFormat.format(weekSummary.spentAmount)}원 / ${numberFormat.format(weekSummary.budgetAmount)}원',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${weekSummary.usageRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              weekSummary.remainingAmount >= 0
                  ? '남은 금액: ${numberFormat.format(weekSummary.remainingAmount)}원'
                  : '초과 금액: ${numberFormat.format(weekSummary.remainingAmount.abs())}원',
              style: TextStyle(
                fontSize: 12,
                color: weekSummary.remainingAmount >= 0
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'UNDER' => Colors.green,
      'OVER' => Colors.red,
      'IN_PROGRESS' => Colors.blue,
      _ => Colors.grey,
    };
  }

  String _getStatusLabel(String status) {
    return switch (status) {
      'UNDER' => '예산 이내',
      'OVER' => '예산 초과',
      'IN_PROGRESS' => '진행 중',
      _ => status,
    };
  }
}
