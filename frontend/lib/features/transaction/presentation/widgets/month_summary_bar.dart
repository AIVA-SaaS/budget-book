import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';

class MonthSummaryBar extends StatelessWidget {
  final int totalIncome;
  final int totalExpense;
  final int balance;
  final int? totalTransfer;

  const MonthSummaryBar({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    this.totalTransfer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildItem(
              context,
              label: '수입',
              amount: totalIncome,
              color: Colors.blue,
            ),
          ),
          Expanded(
            child: _buildItem(
              context,
              label: '지출',
              amount: totalExpense,
              color: Colors.red,
            ),
          ),
          if (totalTransfer != null && totalTransfer! > 0)
            Expanded(
              child: _buildItem(
                context,
                label: '이체',
                amount: totalTransfer!,
                color: Colors.teal,
              ),
            ),
          Expanded(
            child: _buildItem(
              context,
              label: '합계',
              amount: balance,
              color: balance >= 0 ? Colors.blue : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required String label,
    required int amount,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${CurrencyFormatter.format(amount)}원',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
