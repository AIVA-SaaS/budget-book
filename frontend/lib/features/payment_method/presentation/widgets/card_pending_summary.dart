import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/payment_method/domain/entities/card_pending.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';

class CardPendingSummary extends StatelessWidget {
  final List<CardPending> cardPendings;

  const CardPendingSummary({super.key, required this.cardPendings});

  @override
  Widget build(BuildContext context) {
    final totalPending =
        cardPendings.fold<int>(0, (sum, cp) => sum + cp.pendingAmount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.credit_score,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '카드 결제 예정',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${CurrencyFormatter.format(totalPending)}원',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            if (cardPendings.length > 1) ...[
              const Divider(height: 24),
              ...cardPendings.map((cp) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cp.paymentMethod.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                cp.settlementDate != null
                                    ? '결제일: ${cp.settlementDate} (${cp.transactionCount}건)'
                                    : '${cp.transactionCount}건',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${CurrencyFormatter.format(cp.pendingAmount)}원',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
