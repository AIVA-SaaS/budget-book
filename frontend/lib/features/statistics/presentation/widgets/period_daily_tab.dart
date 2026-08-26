import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/bb_card_tile.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/statistics/domain/entities/period_summary.dart';

class PeriodDailyTab extends StatelessWidget {
  final List<PeriodDateItem> items;

  const PeriodDailyTab({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('해당 기간에 일별 데이터가 없습니다',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBarChart(context),
          const SizedBox(height: 24),
          // ★항목 사이는 **호스트**가 소유한다.
          ...bbCardItems(context,
              items.map((item) => _DailyListItem(item: item)).toList()),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context) {
    final maxAmount = items.fold<int>(0, (max, item) {
      final m = item.income > item.expense ? item.income : item.expense;
      return m > max ? m : max;
    });
    final maxY = maxAmount > 0 ? maxAmount * 1.2 : 100000.0;
    final df = DateFormat('M/d');

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = items[group.x.toInt()];
                final label = rodIndex == 0 ? '수입' : '지출';
                final amount = rodIndex == 0 ? item.income : item.expense;
                return BarTooltipItem(
                  '$label: ${CurrencyFormatter.format(amount)}원',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= items.length) {
                    return const SizedBox.shrink();
                  }
                  // Show every nth label to avoid overlap
                  final step = (items.length / 7).ceil().clamp(1, items.length);
                  if (index % step != 0 && index != items.length - 1) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime.tryParse(items[index].date);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      date != null ? df.format(date) : '',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
                reservedSize: 24,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    CurrencyFormatter.toKoreanUnit(value.toInt()),
                    style: const TextStyle(fontSize: 9),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          barGroups: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: item.income.toDouble(),
                  color: Colors.blue.withValues(alpha: 0.7),
                  width: items.length > 15 ? 4 : 8,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(2)),
                ),
                BarChartRodData(
                  toY: item.expense.toDouble(),
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.7),
                  width: items.length > 15 ? 4 : 8,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(2)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DailyListItem extends StatelessWidget {
  final PeriodDateItem item;

  const _DailyListItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(item.date);
    final dateLabel =
        date != null ? DateFormat('M월 d일 (E)', 'ko').format(date) : item.date;

    // 세로 리듬은 BbCardTile 이 소유한다(사이 20.0dp @390 · 25.0 @960).
    return BbCardTile(
      hPadding: BbSpaceToken.xl,
      child: Row(
        children: [
          Expanded(
            child:
                Text(dateLabel, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (item.income > 0)
            Text(
              '+${CurrencyFormatter.format(item.income)}원',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          if (item.income > 0 && item.expense > 0) const SizedBox(width: 12),
          if (item.expense > 0)
            Text(
              '-${CurrencyFormatter.format(item.expense)}원',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
        ],
      ),
    );
  }
}
