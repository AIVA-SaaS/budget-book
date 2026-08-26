import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import '../../../../core/theme/bb_scale.dart';

class MonthlyTrendTab extends StatelessWidget {
  final List<MonthlyTrend> trends;
  final bool isLoading;
  final String? error;

  const MonthlyTrendTab({
    super.key,
    required this.trends,
    this.isLoading = false,
    this.error,
  });

  static const _incomeColor = Color(0xFF4CAF50);
  static const _expenseColor = Color(0xFFF44336);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            context.bbSpace.gapV(BbSpaceToken.xxl),
            Text(error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (trends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            context.bbSpace.gapV(BbSpaceToken.xxl),
            Text(
              '추이 데이터가 없습니다',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Legend
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: _incomeColor, label: '수입'),
              SizedBox(width: 24),
              _LegendItem(color: _expenseColor, label: '지출'),
            ],
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // Line chart
          SizedBox(
            height: 250,
            child: LineChart(_buildLineChartData(context)),
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          // Monthly table
          _buildTable(context),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData(BuildContext context) {
    final maxY = trends.fold<int>(
            0,
            (max, t) => [max, t.totalIncome, t.totalExpense]
                .reduce((a, b) => a > b ? a : b)) /
        10000;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 100,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.1),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.toInt()}만',
                style: TextStyle(fontSize: context.bbType.caption),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= trends.length) return const Text('');
              final ym = trends[index].yearMonth;
              // Show month only: "3월"
              final month = ym.split('-').last;
              return Text(
                '${int.parse(month)}월',
                style: TextStyle(fontSize: context.bbType.caption),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        // Income line
        LineChartBarData(
          spots: trends
              .asMap()
              .entries
              .map((e) => FlSpot(
                  e.key.toDouble(), e.value.totalIncome / 10000))
              .toList(),
          isCurved: true,
          color: _incomeColor,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: _incomeColor.withValues(alpha: 0.1),
          ),
        ),
        // Expense line
        LineChartBarData(
          spots: trends
              .asMap()
              .entries
              .map((e) => FlSpot(
                  e.key.toDouble(), e.value.totalExpense / 10000))
              .toList(),
          isCurved: true,
          color: _expenseColor,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: _expenseColor.withValues(alpha: 0.1),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final isIncome = spot.barIndex == 0;
              return LineTooltipItem(
                '${isIncome ? "수입" : "지출"}: ${CurrencyFormatter.format((spot.y * 10000).toInt())}원',
                TextStyle(
                  color: isIncome ? _incomeColor : _expenseColor,
                  fontWeight: FontWeight.bold,
                  fontSize: context.bbType.label,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.5),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                  ),
                ),
              ),
              children: const [
                _TableHeader('월'),
                _TableHeader('수입'),
                _TableHeader('지출'),
                _TableHeader('잔액'),
              ],
            ),
            ...trends.map((t) {
              final month = t.yearMonth.split('-').last;
              return TableRow(
                children: [
                  _TableCell('${int.parse(month)}월'),
                  _TableCell(
                    '${CurrencyFormatter.format(t.totalIncome)}원',
                    color: _incomeColor,
                  ),
                  _TableCell(
                    '${CurrencyFormatter.format(t.totalExpense)}원',
                    color: _expenseColor,
                  ),
                  _TableCell(
                    '${CurrencyFormatter.format(t.balance)}원',
                    color: const Color(0xFF2196F3),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final Color? color;
  const _TableCell(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        textAlign: TextAlign.right,
      ),
    );
  }
}
