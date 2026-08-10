import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/utils/ledger_route.dart';
import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';

/// 분석 탭 상단 카드 — 그 달의 장부 항목 중 아직 정산 스냅샷에 담기지 않은
/// 건수를 보여준다 ("월말 점검 · 미기록 N건").
///
/// Wording follows the ledger screen verbatim (미기록, not 미정산) — see
/// `reconciliation_view.dart`. Subtotals are rendered exactly as the server
/// computed them; the client never re-sums them, because the server re-computes
/// subtotals after viewer gating (partner PRIVATE rows) and any client-side sum
/// would drift from the rows actually visible.
class ReconciliationSummaryCard extends StatelessWidget {
  final ReconciliationSummary summary;
  final int year;
  final int month;

  const ReconciliationSummaryCard({
    super.key,
    required this.summary,
    required this.year,
    required this.month,
  });

  /// Navigates to the ledger's reconciliation view for **the month being shown
  /// on the analysis tab** — not "today". Carrying year/month is the whole point of
  /// [ledgerLocation]'s required parameters (navigation_state incidents).
  void _openLedger(BuildContext context) {
    context.go(ledgerLocation(
      year: year,
      month: month,
      view: LedgerView.reconciliation,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = summary.isFullyReconciled;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openLedger(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fact_check,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '월말 점검',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _openLedger(context),
                    child: const Text('더보기'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (done)
                _StatusLine(
                  icon: Icons.check_circle,
                  color: theme.colorScheme.primary,
                  text: '이 달은 정산 완료입니다',
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '미기록 ${summary.unrecordedCount}건',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (summary.needsReviewCount > 0) ...[
                      const SizedBox(width: 10),
                      _NeedsReviewChip(count: summary.needsReviewCount),
                    ],
                  ],
                ),
                if (_subtotalText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _subtotalText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Server-computed subtotals, joined. Empty when every subtotal is zero.
  String get _subtotalText => [
        if (summary.unrecordedExpense > 0)
          '지출 ${CurrencyFormatter.format(summary.unrecordedExpense)}',
        if (summary.unrecordedIncome > 0)
          '수입 ${CurrencyFormatter.format(summary.unrecordedIncome)}',
        if (summary.unrecordedTransfer > 0)
          '이체 ${CurrencyFormatter.format(summary.unrecordedTransfer)}',
      ].join(' · ');
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _NeedsReviewChip extends StatelessWidget {
  final int count;

  const _NeedsReviewChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '확인 필요 $count건',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
