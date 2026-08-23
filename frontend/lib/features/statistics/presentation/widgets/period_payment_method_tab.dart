import 'package:flutter/material.dart';
import 'package:budget_book/core/widgets/bb_card_tile.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/statistics/domain/entities/period_summary.dart';

class PeriodPaymentMethodTab extends StatelessWidget {
  final List<PeriodPaymentMethodItem> items;

  const PeriodPaymentMethodTab({super.key, required this.items});

  static const _defaultColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFFF5733),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFF795548),
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('해당 기간에 결제 데이터가 없습니다',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    final sorted = List<PeriodPaymentMethodItem>.from(items)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final totalAmount = sorted.fold(0, (sum, item) => sum + item.amount);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        final color = _defaultColors[index % _defaultColors.length];
        final percentage =
            totalAmount > 0 ? item.amount / totalAmount * 100 : 0.0;

        // 세로 리듬은 BbCardTile 이 소유한다(사이 20.0dp @390 · 25.0 @960).
        return BbCardTile(
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.methodName,
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (percentage / 100).clamp(0.0, 1.0),
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${CurrencyFormatter.format(item.amount)}원',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}% (${item.count}건)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
