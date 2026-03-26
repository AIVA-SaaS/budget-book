import 'package:flutter/material.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';

class YearComparisonTab extends StatelessWidget {
  final StatisticsSummary? currentYear;
  final StatisticsSummary? previousYear;
  final bool isLoading;
  final String? error;
  final int year;
  final int month;

  const YearComparisonTab({
    super.key,
    this.currentYear,
    this.previousYear,
    this.isLoading = false,
    this.error,
    required this.year,
    required this.month,
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
    if (currentYear == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.compare_arrows,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '비교할 데이터가 없습니다',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
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
          _ComparisonCard(
            title: '수입',
            currentAmount: currentYear!.totalIncome,
            previousAmount: previousYear?.totalIncome,
            color: const Color(0xFF4CAF50),
            icon: Icons.arrow_downward,
            year: year,
          ),
          const SizedBox(height: 12),
          _ComparisonCard(
            title: '지출',
            currentAmount: currentYear!.totalExpense,
            previousAmount: previousYear?.totalExpense,
            color: const Color(0xFFF44336),
            icon: Icons.arrow_upward,
            year: year,
          ),
          const SizedBox(height: 12),
          _ComparisonCard(
            title: '잔액',
            currentAmount: currentYear!.balance,
            previousAmount: previousYear?.balance,
            color: const Color(0xFF2196F3),
            icon: Icons.account_balance_wallet,
            year: year,
          ),
          const SizedBox(height: 12),
          _ComparisonCard(
            title: '거래 건수',
            currentAmount: currentYear!.transactionCount,
            previousAmount: previousYear?.transactionCount,
            color: const Color(0xFF9C27B0),
            icon: Icons.receipt_long,
            year: year,
            isCount: true,
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final String title;
  final int currentAmount;
  final int? previousAmount;
  final Color color;
  final IconData icon;
  final int year;
  final bool isCount;

  const _ComparisonCard({
    required this.title,
    required this.currentAmount,
    this.previousAmount,
    required this.color,
    required this.icon,
    required this.year,
    this.isCount = false,
  });

  @override
  Widget build(BuildContext context) {
    final suffix = isCount ? '건' : '원';

    String? changeText;
    Color? changeColor;

    if (previousAmount != null && previousAmount! > 0) {
      final diff = currentAmount - previousAmount!;
      final pct = (diff / previousAmount! * 100).round();
      final sign = pct >= 0 ? '+' : '';
      changeText = '$sign$pct%';
      changeColor = pct >= 0 ? Colors.green : Colors.red;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (changeText != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: changeColor!.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      changeText,
                      style: TextStyle(
                        color: changeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Current year
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$year년',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
                Text(
                  '${CurrencyFormatter.format(currentAmount)}$suffix',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
              ],
            ),
            const Divider(height: 16),
            // Previous year
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${year - 1}년',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                ),
                Text(
                  previousAmount != null
                      ? '${CurrencyFormatter.format(previousAmount!)}$suffix'
                      : '데이터 없음',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
