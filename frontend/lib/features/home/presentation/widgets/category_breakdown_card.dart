import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';

/// Dashboard card showing a compact donut chart of top category spending.
class CategoryBreakdownCard extends StatelessWidget {
  final List<CategoryStatistics> categoryStats;
  final Map<String, dynamic> settings;

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

  const CategoryBreakdownCard({
    super.key,
    required this.categoryStats,
    this.settings = const {},
  });

  int get _count {
    final val = settings['count'];
    if (val is int) return val;
    return 5;
  }

  String get _type {
    final val = settings['type'];
    if (val is String) return val;
    return 'EXPENSE';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topStats = categoryStats.take(_count).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.donut_large, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '카테고리별 현황',
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
            if (topStats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    _type == 'EXPENSE'
                        ? '이번 달 지출 내역이 없습니다'
                        : '이번 달 수입 내역이 없습니다',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Donut chart
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 28,
                        sections: topStats.asMap().entries.map((entry) {
                          final color = _defaultColors[entry.key % _defaultColors.length];
                          return PieChartSectionData(
                            value: entry.value.percentage,
                            color: color,
                            radius: 28,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Legend + amounts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: topStats.asMap().entries.map((entry) {
                        final stat = entry.value;
                        final color = _defaultColors[entry.key % _defaultColors.length];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  stat.category.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${CurrencyFormatter.format(stat.amount)}원',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
