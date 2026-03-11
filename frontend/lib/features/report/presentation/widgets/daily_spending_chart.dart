import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/report/domain/entities/weekly_report.dart';

class DailySpendingChart extends StatelessWidget {
  final List<DailySpending> dailySpending;
  final String peakSpendingDay;

  const DailySpendingChart({
    super.key,
    required this.dailySpending,
    required this.peakSpendingDay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');
    final maxAmount = dailySpending.isEmpty
        ? 1
        : dailySpending
            .map((d) => d.amount)
            .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '일별 지출',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '최다 지출: ${_dayOfWeekLabel(peakSpendingDay)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...dailySpending.map((day) {
              final ratio = maxAmount > 0 ? day.amount / maxAmount : 0.0;
              final isPeak = day.dayOfWeek == peakSpendingDay;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        _dayOfWeekLabel(day.dayOfWeek),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isPeak ? FontWeight.bold : FontWeight.normal,
                          color: isPeak
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 20,
                          backgroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isPeak
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        '${numberFormat.format(day.amount)}원',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isPeak ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _dayOfWeekLabel(String day) {
    return switch (day) {
      'MON' => '월',
      'TUE' => '화',
      'WED' => '수',
      'THU' => '목',
      'FRI' => '금',
      'SAT' => '토',
      'SUN' => '일',
      _ => day,
    };
  }
}
