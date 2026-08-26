import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import '../../../../core/theme/bb_scale.dart';

/// Shows budget alerts on the dashboard for categories that are
/// at WARNING (>=80%) or EXCEEDED (>=100%) usage levels.
class BudgetAlertWidget extends StatelessWidget {
  const BudgetAlertWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is! DashboardLoaded) return const SizedBox.shrink();
        if (state.budgetSummary == null) return const SizedBox.shrink();

        final alertItems = state.budgetSummary!.items
            .where((item) => item.usageRate >= 80)
            .toList()
          ..sort((a, b) => b.usageRate.compareTo(a.usageRate));

        if (alertItems.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: context.bbType.iconSm,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '예산 알림',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            ...alertItems.map(
              (item) => _BudgetAlertCard(item: item),
            ),
          ],
        );
      },
    );
  }
}

class _BudgetAlertCard extends StatelessWidget {
  final BudgetSummaryItem item;

  const _BudgetAlertCard({required this.item});


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExceeded = item.usageRate >= 100;
    final alertColor = isExceeded ? theme.colorScheme.error : Colors.orange;
    final bgColor = isExceeded
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.5)
        : Colors.orange.withValues(alpha: 0.1);

    return Card(
      color: bgColor,
      elevation: 0,
      // ★세로는 호스트가 갖는다 — 카드는 자기 밖을 소유하지 않는다.
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.category?.displayName ?? item.groupName ?? '전체',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isExceeded ? '초과' : '주의',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: alertColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            context.bbSpace.gapV(BbSpaceToken.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (item.usageRate / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: alertColor,
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${CurrencyFormatter.format(item.spentAmount)}원 / ${CurrencyFormatter.format(item.budgetAmount)}원',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${item.usageRate.toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: alertColor,
                    fontWeight: FontWeight.bold,
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
