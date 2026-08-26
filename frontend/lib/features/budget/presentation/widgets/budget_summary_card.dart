import 'package:flutter/material.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import '../../../../core/theme/bb_scale.dart';

class BudgetSummaryCard extends StatelessWidget {
  final BudgetSummary summary;

  const BudgetSummaryCard({
    super.key,
    required this.summary,
    this.embedded = false,
    this.expanded,
    this.onToggle,
  });

  /// true 면 **자체 `Card` 를 두르지 않는다** — 부모가 하나의 카드를 소유하고
  /// 예산 항목들을 같은 카드 안에 품는 구조(2026-08-26, 8차)에서 쓴다.
  /// 기본 false 라 기존 호출부 동작은 그대로다.
  final bool embedded;

  /// 접힘 여부. [onToggle] 과 함께 주면 헤더 우측에 chevron 이 붙는다.
  /// ★`ExpansionTile` 을 쓰지 않는 이유 = 2026-07-27 에 `trailing` 을 다른 위젯이
  ///   덮어써 **펼침 chevron 이 통째로 사라진** 인시던트가 있었다. 헤더 행에
  ///   명시적으로 두면 다른 액션이 그 자리를 못 가져간다.
  final bool? expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final remaining = summary.remainingAmount;
    final isOver = summary.isOverBudget;
    final rate = summary.usageRate.clamp(0.0, 100.0) / 100.0;

    final content = Padding(
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${CurrencyFormatter.format(summary.totalBudget)}원',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (onToggle != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon((expanded ?? true)
                            ? Icons.expand_less
                            : Icons.expand_more),
                        tooltip: (expanded ?? true) ? '예산 항목 접기' : '예산 항목 펼치기',
                        // ★visualDensity 를 국소로 주지 않는다 — 밀도는
                        //   `AppTheme._densityFor` 하나가 정한다(가드 S3).
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onToggle,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),
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
            context.bbSpace.gapV(BbSpaceToken.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    // 회차 12 P4 — 도메인 분리: 계획 정보 제거. 지출만 표시.
                    '지출: ${CurrencyFormatter.format(summary.totalSpent)}원',
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
      );

    if (embedded) return content;
    return Card(
      // ★세로는 블록 축(`gapV(block)`)이 갖는다 — 가로만 남긴다.
      margin: EdgeInsets.symmetric(horizontal: context.bbSpace.xxl),
      child: content,
    );
  }

  Color _getProgressColor(double usageRate) {
    if (usageRate > 100) return Colors.red;
    if (usageRate >= 80) return Colors.orange;
    return Colors.green;
  }
}
