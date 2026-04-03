import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';

/// Shared month navigation widget with prev/next buttons and month picker.
/// Used across budget, transaction, statistics, and report pages.
class MonthNavigator extends StatelessWidget {
  final int year;
  final int month;
  final ValueChanged<({int year, int month})> onMonthChanged;
  /// Called when user picks a specific date (day) from the calendar.
  /// If null, only year/month is used.
  final ValueChanged<DateTime>? onDatePicked;

  const MonthNavigator({
    super.key,
    required this.year,
    required this.month,
    required this.onMonthChanged,
    this.onDatePicked,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('yyyy년 M월').format(DateTime(year, month));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = month == 1
                  ? (year: year - 1, month: 12)
                  : (year: year, month: month - 1);
              onMonthChanged(prev);
            },
            tooltip: '이전 달',
          ),
          TextButton(
            onPressed: () async {
              final picked = await showCalendarPickerDialog(
                context: context,
                initialDate: DateTime(year, month),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030, 12, 31),
              );
              if (picked != null && context.mounted) {
                if (onDatePicked != null) {
                  onDatePicked!(picked);
                }
                onMonthChanged((year: picked.year, month: picked.month));
              }
            },
            child: Text(
              dateStr,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = month == 12
                  ? (year: year + 1, month: 1)
                  : (year: year, month: month + 1);
              onMonthChanged(next);
            },
            tooltip: '다음 달',
          ),
        ],
      ),
    );
  }
}
