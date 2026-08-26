import 'package:flutter/material.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/bb_card_tile.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/statistics/domain/entities/period_summary.dart';

class PeriodBudgetTab extends StatelessWidget {
  final List<PeriodBudgetItem> items;

  const PeriodBudgetTab({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
            context.bbSpace.gapV(BbSpaceToken.xxl),
            Text('해당 기간에 예산 데이터가 없습니다',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    // ★항목 사이는 **호스트**가 소유한다 — 카드는 자기 밖을 소유하지 않으므로
    // `.builder` 가 아니라 `.separated` 로 사이를 명시한다.
    return ListView.separated(
      separatorBuilder: (_, __) => const BbCardGap(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final progress = item.budgetAmount > 0
            ? (item.spent / item.budgetAmount).clamp(0.0, 1.0)
            : 0.0;
        final isOverBudget = item.spent > item.budgetAmount;
        final progressColor = isOverBudget
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary;

        // 세로 리듬은 BbCardTile 이 소유한다(사이 20.0dp @390 · 25.0 @960).
        return BbCardTile(
          hPadding: BbSpaceToken.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.budgetName,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isOverBudget)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '초과',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              context.bbSpace.gapV(BbSpaceToken.xl),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: progressColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 8,
                ),
              ),
              context.bbSpace.gapV(BbSpaceToken.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '사용: ${CurrencyFormatter.format(item.spent)}원',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '계획: ${CurrencyFormatter.format(item.budgetAmount)}원',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              context.bbSpace.gapV(BbSpaceToken.xs),
              Text(
                '남은 금액: ${CurrencyFormatter.format(item.remaining)}원',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: item.remaining >= 0
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
