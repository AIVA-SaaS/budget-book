import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/bb_card_tile.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/statistics/domain/entities/period_summary.dart';

class PeriodCategoryTab extends StatelessWidget {
  final List<PeriodCategoryItem> items;

  const PeriodCategoryTab({super.key, required this.items});

  static const _defaultColors = [
    Color(0xFFFF5733),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFFCDDC39),
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
            context.bbSpace.gapV(BbSpaceToken.xxl),
            Text('해당 기간에 데이터가 없습니다',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    final sorted = List<PeriodCategoryItem>.from(items)
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(PieChartData(
              sections: sorted.asMap().entries.map((entry) {
                final color = _defaultColors[entry.key % _defaultColors.length];
                final item = entry.value;
                return PieChartSectionData(
                  value: item.amount.toDouble(),
                  title: item.percentage >= 5
                      ? '${item.percentage.toStringAsFixed(0)}%'
                      : '',
                  color: color,
                  radius: 60,
                  titleStyle: TextStyle(
                      fontSize: context.bbType.label,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              }).toList(),
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            )),
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          // ★항목 사이는 **호스트**가 소유한다.
          ...bbCardItems(context, sorted.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final color = _defaultColors[index % _defaultColors.length];
            return _CategoryListItem(item: item, color: color);
          }).toList()),
        ],
      ),
    );
  }
}

class _CategoryListItem extends StatelessWidget {
  final PeriodCategoryItem item;
  final Color color;

  const _CategoryListItem({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    // 세로 리듬은 BbCardTile 이 소유한다(사이 20.0dp @390 · 25.0 @960).
    return BbCardTile(
      hMargin: BbSpaceToken.md,
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
                Text(item.categoryName,
                    style: Theme.of(context).textTheme.bodyLarge),
                context.bbSpace.gapV(BbSpaceToken.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (item.percentage / 100).clamp(0.0, 1.0),
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
                '${item.percentage.toStringAsFixed(1)}% (${item.count}건)',
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
  }
}
