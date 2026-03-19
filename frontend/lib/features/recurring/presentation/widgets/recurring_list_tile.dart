import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/recurring/domain/entities/recurring_transaction.dart';

class RecurringListTile extends StatelessWidget {
  final RecurringTransaction transaction;
  final ValueChanged<bool>? onActiveChanged;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const RecurringListTile({
    super.key,
    required this.transaction,
    this.onActiveChanged,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');
    final typeColor = transaction.isExpense ? Colors.red : Colors.blue;

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('반복 거래 삭제'),
            content: Text("'${transaction.description}' 반복 거래를 삭제하시겠습니까?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('삭제'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          onDelete?.call();
        }
        return confirmed ?? false;
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.1),
          child: Icon(
            transaction.isExpense ? Icons.arrow_downward : Icons.arrow_upward,
            color: typeColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            if (transaction.isPrivate) ...[
              Icon(
                Icons.lock,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                transaction.description,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                transaction.frequencyLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaction.categoryName != null)
              Text(
                transaction.categoryName!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            Text(
              '다음 실행: ${transaction.nextRunDate}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${transaction.isExpense ? '-' : '+'}${numberFormat.format(transaction.amount)}원',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: transaction.isActive,
              onChanged: onActiveChanged,
            ),
          ],
        ),
      ),
    );
  }
}
