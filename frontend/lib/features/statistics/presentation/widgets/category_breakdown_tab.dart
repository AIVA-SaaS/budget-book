import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';

class CategoryBreakdownTab extends StatelessWidget {
  final List<CategoryStatistics> categoryStats;
  final bool isLoading;
  final String? error;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;

  const CategoryBreakdownTab({
    super.key,
    required this.categoryStats,
    this.isLoading = false,
    this.error,
    this.selectedType = 'EXPENSE',
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Type toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'EXPENSE', label: Text('지출')),
              ButtonSegment(value: 'INCOME', label: Text('수입')),
            ],
            selected: {selectedType},
            onSelectionChanged: (set) => onTypeChanged(set.first),
          ),
        ),
        Expanded(
          child: _buildContent(context),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (categoryStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '이 달에 기록된 거래가 없습니다',
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
          // Pie chart
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: _buildPieSections(),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Category list
          ...categoryStats.map((stat) => _CategoryListItem(stat: stat)),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final defaultColors = [
      const Color(0xFFFF5733),
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFE91E63),
      const Color(0xFF795548),
    ];

    return categoryStats.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;
      final color = stat.category.color != null && stat.category.color!.isNotEmpty
          ? UIHelpers.parseColor(stat.category.color,
              fallback: defaultColors[index % defaultColors.length])
          : defaultColors[index % defaultColors.length];

      return PieChartSectionData(
        value: stat.amount.toDouble(),
        title: '${stat.percentage.toStringAsFixed(1)}%',
        color: color,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

}

class _CategoryListItem extends StatelessWidget {
  final CategoryStatistics stat;

  const _CategoryListItem({required this.stat});

  @override
  Widget build(BuildContext context) {
    final categoryColor = UIHelpers.parseColor(
      stat.category.color,
      fallback: const Color(0xFFFF5733),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.category.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    // Percentage bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stat.percentage / 100,
                        backgroundColor: categoryColor.withValues(alpha: 0.1),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(categoryColor),
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
                    '${CurrencyFormatter.format(stat.amount)}원',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${stat.percentage.toStringAsFixed(1)}% (${stat.transactionCount}건)',
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
        ),
      ),
    );
  }
}
