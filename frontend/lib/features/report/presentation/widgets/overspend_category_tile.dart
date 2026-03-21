import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/report/domain/entities/weekly_report.dart';

class OverspendCategoryTile extends StatelessWidget {
  final OverspendCategory category;

  const OverspendCategoryTile({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverAverage = category.deviation > 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: UIHelpers.parseColor(category.categoryColor)
            .withValues(alpha: 0.15),
        child: Icon(
          Icons.category,
          color: UIHelpers.parseColor(category.categoryColor),
          size: 20,
        ),
      ),
      title: Text(
        category.categoryName,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '평균 ${CurrencyFormatter.format(category.averageAmount)}원 (${category.transactionCount}건)',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${CurrencyFormatter.format(category.amount)}원',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOverAverage ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: isOverAverage ? Colors.red : Colors.green,
              ),
              Text(
                '${CurrencyFormatter.format(category.deviation.abs())}원',
                style: TextStyle(
                  fontSize: 12,
                  color: isOverAverage ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
