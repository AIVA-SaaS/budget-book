import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';

class BudgetSummaryCard extends StatelessWidget {
  final BudgetSummary summary;

  const BudgetSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final remaining = summary.remainingAmount;
    final isOver = summary.isOverBudget;
    final rate = summary.usageRate.clamp(0.0, 100.0) / 100.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '이번 달 예산',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${CurrencyFormatter.format(summary.totalBudget)}원',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 12,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                color: _getProgressColor(summary.usageRate),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '지출: ${CurrencyFormatter.format(summary.totalSpent)}원',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  isOver
                      ? '${CurrencyFormatter.format(-remaining)}원 초과'
                      : '${CurrencyFormatter.format(remaining)}원 남음',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isOver ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double usageRate) {
    if (usageRate > 100) return Colors.red;
    if (usageRate >= 80) return Colors.orange;
    return Colors.green;
  }
}
