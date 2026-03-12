import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';

class TransactionListTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionListTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  static final _formatter = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
    final amountColor = isExpense ? Colors.red : Colors.blue;
    final amountPrefix = isExpense ? '-' : '+';
    final category = transaction.category;
    final iconColor = _parseColor(category?.color);

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
        return await _showDeleteConfirm(context);
      },
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.15),
          child: Icon(
            _resolveIcon(category?.icon),
            color: iconColor,
            size: 20,
          ),
        ),
        title: Text(
          transaction.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              category?.name ?? '미분류',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$amountPrefix${_formatter.format(transaction.amount)}원',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
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

  Future<bool?> _showDeleteConfirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('거래 삭제'),
        content: const Text('이 거래를 삭제하시겠습니까?'),
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
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    try {
      final colorStr = hex.replaceFirst('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _resolveIcon(String? iconName) {
    if (iconName == null) return Icons.receipt_long;
    const iconMap = <String, IconData>{
      'restaurant': Icons.restaurant,
      'restaurant_menu': Icons.restaurant_menu,
      'shopping_cart': Icons.shopping_cart,
      'directions_bus': Icons.directions_bus,
      'home': Icons.home,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'pets': Icons.pets,
      'payments': Icons.payments,
      'work': Icons.work,
      'savings': Icons.savings,
      'card_giftcard': Icons.card_giftcard,
      'trending_up': Icons.trending_up,
      'local_cafe': Icons.local_cafe,
      'movie': Icons.movie,
      'fitness_center': Icons.fitness_center,
      'child_care': Icons.child_care,
      'phone': Icons.phone,
      'electric_bolt': Icons.electric_bolt,
      'account_balance': Icons.account_balance,
    };
    return iconMap[iconName] ?? Icons.receipt_long;
  }
}
