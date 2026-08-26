import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/report/domain/entities/monthly_report.dart';
import '../../../../core/theme/bb_scale.dart';

class MonthComparisonCard extends StatelessWidget {
  final MonthComparison comparison;

  const MonthComparisonCard({super.key, required this.comparison});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '전월 대비 (${comparison.previousYearMonth})',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            context.bbSpace.gapV(BbSpaceToken.xxl),
            Row(
              children: [
                Expanded(
                  child: _buildComparisonItem(
                    context,
                    label: '수입',
                    amount: comparison.incomeChange,
                    rate: comparison.incomeChangeRate,
                    isIncome: true,
                    numberFormat: numberFormat,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildComparisonItem(
                    context,
                    label: '지출',
                    amount: comparison.expenseChange,
                    rate: comparison.expenseChangeRate,
                    isIncome: false,
                    numberFormat: numberFormat,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonItem(
    BuildContext context, {
    required String label,
    required int amount,
    required double rate,
    required bool isIncome,
    required NumberFormat numberFormat,
  }) {
    final theme = Theme.of(context);
    // For income: increase is good (green), decrease is bad (red)
    // For expense: decrease is good (green), increase is bad (red)
    final isPositive = isIncome ? amount >= 0 : amount <= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = amount >= 0 ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          context.bbSpace.gapV(BbSpaceToken.lg),
          Row(
            children: [
              Icon(icon, size: context.bbType.iconSm, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${numberFormat.format(amount.abs())}원',
                  style: TextStyle(
                    fontSize: context.bbType.section,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          context.bbSpace.gapV(BbSpaceToken.xs),
          Text(
            '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: context.bbType.label,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
