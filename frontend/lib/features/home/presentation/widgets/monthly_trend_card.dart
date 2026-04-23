import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';

/// Dashboard card showing a compact line chart of recent monthly income/expense trends.
class MonthlyTrendCard extends StatelessWidget {
  final List<MonthlyTrend> trends;
  final Map<String, dynamic> settings;

  static const _incomeColor = Color(0xFF4CAF50);
  static const _expenseColor = Color(0xFFF44336);
  static const _balanceColor = Color(0xFF2196F3);

  const MonthlyTrendCard({
    super.key,
    required this.trends,
    this.settings = const {},
  });

  int get _months {
    final val = settings['months'];
    if (val is int) return val;
    return 6;
  }

  List<String> get _showItems {
    final val = settings['showItems'];
    if (val is List) return val.cast<String>();
    return ['income', 'expense'];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayTrends = trends.length > _months
        ? trends.sublist(trends.length - _months)
        : trends;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '월별 추이',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    final shell = StatefulNavigationShell.maybeOf(context);
                    if (shell != null) {
                      shell.goBranch(3); // Statistics tab
                    }
                  },
                  child: const Text('더보기'),
                ),
              ],
            ),
            if (displayTrends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '추이 데이터가 없습니다',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              // Legend
              _buildLegend(context),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: LineChart(_buildChart(context, displayTrends)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final items = _showItems;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (items.contains('income'))
          const _LegendDot(color: _incomeColor, label: '수입'),
        if (items.contains('expense')) ...[
          if (items.contains('income')) const SizedBox(width: 16),
          const _LegendDot(color: _expenseColor, label: '지출'),
        ],
        if (items.contains('balance')) ...[
          const SizedBox(width: 16),
          const _LegendDot(color: _balanceColor, label: '잔액'),
        ],
      ],
    );
  }

  LineChartData _buildChart(BuildContext context, List<MonthlyTrend> data) {
    final items = _showItems;
    final theme = Theme.of(context);

    // Find max value for Y axis
    int maxVal = 0;
    for (final t in data) {
      if (items.contains('income') && t.totalIncome > maxVal) maxVal = t.totalIncome;
      if (items.contains('expense') && t.totalExpense > maxVal) maxVal = t.totalExpense;
      if (items.contains('balance') && t.balance.abs() > maxVal) maxVal = t.balance.abs();
    }
    final maxY = maxVal / 10000;

    final lineBars = <LineChartBarData>[];
    if (items.contains('income')) {
      lineBars.add(_buildLine(data, (t) => t.totalIncome / 10000, _incomeColor));
    }
    if (items.contains('expense')) {
      lineBars.add(_buildLine(data, (t) => t.totalExpense / 10000, _expenseColor));
    }
    if (items.contains('balance')) {
      lineBars.add(_buildLine(data, (t) => t.balance / 10000, _balanceColor));
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble().clamp(1, double.infinity) : 100,
        getDrawingHorizontalLine: (value) => FlLine(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            getTitlesWidget: (value, meta) => Text(
              '${value.toInt()}만',
              style: const TextStyle(fontSize: 9),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= data.length) return const Text('');
              final ym = data[index].yearMonth;
              final month = ym.split('-').last;
              return Text(
                '${int.parse(month)}월',
                style: const TextStyle(fontSize: 9),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: lineBars,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final labels = <String>[];
              if (items.contains('income')) labels.add('수입');
              if (items.contains('expense')) labels.add('지출');
              if (items.contains('balance')) labels.add('잔액');
              final label = spot.barIndex < labels.length ? labels[spot.barIndex] : '';
              return LineTooltipItem(
                '$label: ${CurrencyFormatter.format((spot.y * 10000).toInt())}원',
                const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  LineChartBarData _buildLine(
    List<MonthlyTrend> data,
    double Function(MonthlyTrend) getValue,
    Color color,
  ) {
    return LineChartBarData(
      spots: data
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), getValue(e.value)))
          .toList(),
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
