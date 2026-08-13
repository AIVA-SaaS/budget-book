import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/excluded_from_totals_badge.dart';
import 'package:budget_book/core/widgets/reconciled_badge.dart';
import 'package:budget_book/features/transaction/presentation/utils/ledger_totals_exclusion.dart';
import 'package:budget_book/core/utils/couple_mode.dart';
import 'package:budget_book/core/utils/dialog_helpers.dart';
import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';

class TransactionListTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final int? runningTotal;

  const TransactionListTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.runningTotal,
  });


  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
    final isAdjustment = transaction.isAdjustment;
    // ADJUSTMENT amount is signed (positive=increase, negative=decrease).
    // Use its sign for color and explicit + / - prefix.
    final Color amountColor;
    final String amountPrefix;
    if (isAdjustment) {
      amountColor =
          transaction.amount >= 0 ? Colors.green.shade700 : Colors.red.shade700;
      amountPrefix = transaction.amount >= 0 ? '+' : '-';
    } else if (isExpense) {
      amountColor = Colors.red;
      amountPrefix = '-';
    } else {
      amountColor = Colors.blue;
      amountPrefix = '+';
    }
    final category = transaction.category;
    final iconColor = UIHelpers.parseColor(category?.color);

    return Dismissible(
      key: Key(transaction.id),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDeleteConfirmDialog(
          context,
          title: '거래 삭제',
          itemName: transaction.description,
        );
      },
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: SizedBox(
          width: 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: iconColor.withValues(alpha: 0.15),
                child: Icon(
                  UIHelpers.resolveIcon(category?.icon),
                  color: iconColor,
                  size: 16,
                ),
              ),
              if (transaction.paymentMethodName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    transaction.paymentMethodName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45),
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Row(
          children: [
            if (transaction.isPrivate && isCoupleMode()) ...[
              Icon(
                Icons.visibility_off,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
            ],
            // V61 (2026-05-06) — needs_review 뱃지. 사용자가 "확인/입력 필요" 로 마킹한 거래.
            if (transaction.needsReview) ...[
              Tooltip(
                message: '확인/입력 필요',
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            // V65 — 정산 완료 배지 (공통 위젯 ReconciledBadge 단일 소스).
            if (transaction.isReconciled) ...[
              ReconciledBadge(seq: transaction.reconciliationSeq),
              const SizedBox(width: 6),
            ],
            // 2026-08-12 — 합계에 안 잡히는 행임을 행에서 바로 보여준다.
            // 판정은 ledger_totals_exclusion 단일 헬퍼 경유(타일이 직접 판단하지 않는다).
            if (isTransactionExcludedFromTotals(transaction)) ...[
              const ExcludedFromTotalsBadge(
                reason: kAdjustmentExclusionReason,
              ),
              const SizedBox(width: 6),
            ],
            if (isAdjustment) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .tertiaryContainer
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '조정',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                transaction.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              category?.displayName ?? '미분류',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            if (transaction.paymentMethodName != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '·',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  transaction.paymentMethodName!,
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
              ),
            ],
            if (transaction.pocketName != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  transaction.pocketName!,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$amountPrefix${CurrencyFormatter.format(transaction.amount.abs())}원',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: amountColor,
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
                transaction.author.nickname,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
              ),
          ],
        ),
      ),
    );
  }

}
