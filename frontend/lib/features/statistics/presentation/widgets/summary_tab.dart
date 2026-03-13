import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';

class SummaryTab extends StatelessWidget {
  final StatisticsSummary? summary;
  final bool isLoading;
  final String? error;

  const SummaryTab({
    super.key,
    this.summary,
    this.isLoading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (summary == null || summary!.transactionCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '이 달에 기록된 거래가 없습니다',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '거래를 추가하면 통계를 확인할 수 있습니다',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SummaryCard(
            title: '수입',
            amount: summary!.totalIncome,
            color: const Color(0xFF4CAF50),
            icon: Icons.arrow_downward,
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            title: '지출',
            amount: summary!.totalExpense,
            color: const Color(0xFFF44336),
            icon: Icons.arrow_upward,
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            title: '잔액',
            amount: summary!.balance,
            color: const Color(0xFF2196F3),
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '총 ${summary!.transactionCount}건의 거래',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final isNegative = amount < 0;
    final displayAmount = isNegative ? -amount : amount;
    final prefix = isNegative ? '-' : '';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$prefix${formatter.format(displayAmount)}원',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
