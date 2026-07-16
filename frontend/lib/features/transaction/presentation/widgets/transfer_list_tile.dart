import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
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
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '이체',
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
      title: Text(
        transfer.description ?? '이체',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${transfer.sourcePaymentMethod.name} \u2192 ${transfer.destinationPaymentMethod.name}',
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
