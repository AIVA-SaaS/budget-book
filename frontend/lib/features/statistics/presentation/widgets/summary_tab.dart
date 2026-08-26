import 'package:flutter/material.dart';
import 'package:budget_book/core/widgets/bb_card_tile.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';

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
            Icon(Icons.error_outline,
                size: context.bbType.iconLg * 1.5, color: Colors.red),
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
              size: context.bbType.iconLg * 2,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            Text(
              '이 달에 기록된 거래가 없습니다',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            context.bbSpace.gapV(BbSpaceToken.md),
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
      padding: context.bbSpace.all(BbSpaceToken.xl),
      child: Column(
        // ★항목 사이는 **호스트**가 소유한다.
        children: bbCardItems(context, [
          _SummaryCard(
            title: '수입',
            amount: summary!.totalIncome,
            color: const Color(0xFF4CAF50),
            icon: Icons.arrow_downward,
          ),
          _SummaryCard(
            title: '지출',
            amount: summary!.totalExpense,
            color: const Color(0xFFF44336),
            icon: Icons.arrow_upward,
          ),
          _SummaryCard(
            title: '잔액',
            amount: summary!.balance,
            color: const Color(0xFF2196F3),
            icon: Icons.account_balance_wallet,
          ),
          BbCardTile(
            hMargin: BbSpaceToken.md,
            hPadding: BbSpaceToken.xl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: context.bbType.iconMd),
                context.bbSpace.gapH(BbSpaceToken.md),
                Text(
                  '총 ${summary!.transactionCount}건의 거래',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ]),
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
    final isNegative = amount < 0;
    final displayAmount = isNegative ? -amount : amount;
    final prefix = isNegative ? '-' : '';

    // 세로 리듬은 BbCardTile 이 소유한다(사이 20.0dp @390 · 25.0 @960).
    // 종전: 수동 gapV(lg) + margin(theme) + 내부 all(xxl) = 48.8/76.0 `[측정]`.
    return BbCardTile(
      elevation: 2,
      hMargin: BbSpaceToken.md,
      hPadding: BbSpaceToken.xxl,
      child: Row(
        children: [
          Container(
            padding: context.bbSpace.all(BbSpaceToken.lg),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: context.bbSpace.radius(BbSpaceToken.lg),
            ),
            child: Icon(icon, color: color, size: context.bbType.iconLg),
          ),
          context.bbSpace.gapH(BbSpaceToken.xl),
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
                context.bbSpace.gapV(BbSpaceToken.xs),
                Text(
                  '$prefix${CurrencyFormatter.format(displayAmount)}원',
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
    );
  }
}
