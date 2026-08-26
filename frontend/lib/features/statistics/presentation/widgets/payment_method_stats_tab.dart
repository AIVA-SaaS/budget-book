import 'package:budget_book/core/widgets/bb_card_tile.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import '../../../../core/theme/bb_scale.dart';

class PaymentMethodStatsTab extends StatelessWidget {
  final List<PaymentMethodStatistics> stats;
  final bool isLoading;
  final String? error;
  final int year;
  final int month;

  const PaymentMethodStatsTab({
    super.key,
    required this.stats,
    required this.isLoading,
    required this.year,
    required this.month,
    this.error,
  });

  static const _colors = [
    Color(0xFF2196F3),
    Color(0xFFF44336),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFFCDDC39),
  ];

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
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            context.bbSpace.gapV(BbSpaceToken.xl),
            Text(error!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    if (stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),
            Text(
              '결제수단별 통계가 없습니다',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pie chart
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: stats.asMap().entries.map((entry) {
                final index = entry.key;
                final stat = entry.value;
                final color = _colors[index % _colors.length];
                return PieChartSectionData(
                  value: stat.totalAmount.toDouble(),
                  color: color,
                  title: stat.percentage >= 5
                      ? '${stat.percentage.toStringAsFixed(0)}%'
                      : '',
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  radius: 80,
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        context.bbSpace.gapV(BbSpaceToken.block),
        // List of payment methods
        // ★항목 사이는 **호스트**가 소유한다(카드는 자기 밖을 소유하지 않는다).
        ...bbCardItems(context, stats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          final color = _colors[index % _colors.length];

          // 세로 리듬은 BbCardTile 이 소유한다(사이 20.0dp @390 · 25.0 @960).
          // 종전: margin only(bottom: 8) + 내부 all(12) = 사이 32.0/32.0 `[측정]`.
          return BbCardTile(
            onTap: () {
              context.go(
                  '/transactions?year=$year&month=$month&paymentMethodId=${stat.paymentMethodId}&paymentMethodName=${Uri.encodeComponent(stat.paymentMethodName)}');
            },
            child: Row(
              children: [
                // Color indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Payment method info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.paymentMethodName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      context.bbSpace.gapV(BbSpaceToken.xs),
                      Text(
                        '${stat.transactionCount}건',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                      ),
                    ],
                  ),
                ),
                // Amount and percentage
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${CurrencyFormatter.format(stat.totalAmount)}원',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '${stat.percentage.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList()),
      ],
    );
  }
}
