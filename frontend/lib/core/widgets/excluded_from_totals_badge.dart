import 'package:flutter/material.dart';

import 'package:budget_book/features/transaction/presentation/utils/ledger_totals_exclusion.dart';

/// "합계 제외" 배지 — **모든 노출 지점의 단일 소스**.
///
/// 목록에는 보이지만 상단 합계의 어느 칸에도 들어가지 않는 행에 붙인다
/// (잔액 수정 = 통계 범주 밖 / 카드 정산 이체 = 원본 지출로 이미 집계).
/// 표시가 없으면 사용자에게는 "합계가 틀린" 것으로 보인다.
///
/// 판정은 `ledger_totals_exclusion.dart` 가 단독으로 갖는다 — 타일이 직접
/// `isAdjustment`/`kind` 를 보고 배지를 그리면 규칙이 갈라진다.
class ExcludedFromTotalsBadge extends StatelessWidget {
  /// 왜 제외되는지 (툴팁). `ledger_totals_exclusion.dart` 의 상수를 쓴다.
  final String reason;

  const ExcludedFromTotalsBadge({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: reason,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.functions,
              size: 11,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
            Text(
              kExcludedFromTotalsLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
