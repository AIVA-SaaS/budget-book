import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/excluded_from_totals_badge.dart';
import 'package:budget_book/core/widgets/reconciled_badge.dart';
import 'package:budget_book/features/transaction/presentation/utils/ledger_totals_exclusion.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// A list tile for displaying a transfer in the unified transaction list.
/// Styled with blue/teal accent to distinguish from income/expense transactions.
class TransferListTile extends StatelessWidget {
  final Transfer transfer;
  final VoidCallback? onTap;
  /// Asset running balance (MODE B, single-asset filter). When non-null it
  /// replaces the author nickname in the trailing column.
  final int? runningTotal;

  const TransferListTile({
    super.key,
    required this.transfer,
    this.onTap,
    this.runningTotal,
  });

  @override
  Widget build(BuildContext context) {
    const transferColor = Colors.teal;

    return ListTile(
      onTap: onTap,
      leading: SizedBox(
        width: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: transferColor.withValues(alpha: 0.15),
              child: const Icon(
                Icons.swap_horiz,
                color: transferColor,
                size: 16,
              ),
            ),
            // ★2026-08-24 (6차) — 거래 타일과 **같은 선행 계약**(아바타만)으로 맞췄다.
            // 종전에는 아바타 아래 `이체` 캡션(리터럴 fontSize 8 · top 1)이 붙어 선행이
            // 42.4 였고 타일 박스 45 와의 여유가 위아래 1.3dp 뿐이었다 `[측정]`.
            // 표식은 사라지지 않는다 — 부제목 머리로 옮겼다(정보 보존).
          ],
        ),
      ),
      title: Row(
        children: [
          // V65 — 거래 타일과 **동일한** 배지 (두 스트림 표시 일치).
          if (transfer.isReconciled) ...[
            ReconciledBadge(seq: transfer.reconciliationSeq),
            const SizedBox(width: 6),
          ],
          // 2026-08-12 — 카드 정산 이체는 원본 지출로 이미 집계돼 합계에 안 잡힌다.
          // 판정은 ledger_totals_exclusion 단일 헬퍼 경유.
          if (isTransferExcludedFromTotals(transfer)) ...[
            const ExcludedFromTotalsBadge(
              reason: kCardSettlementExclusionReason,
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              transfer.description ?? '이체',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(
        '이체 · ${transfer.sourcePaymentMethod.name} \u2192 ${transfer.destinationPaymentMethod.name}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${CurrencyFormatter.format(transfer.amount)}\uC6D0',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: transferColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (runningTotal != null)
            Text(
              '${CurrencyFormatter.format(runningTotal!)}원',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.35),
              ),
            )
          else
            Text(
              transfer.author.nickname,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
}
