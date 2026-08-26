import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/bb_scale.dart';

/// Shows a date range filter bottom sheet with presets and custom range picker.
///
/// Presets: this week, last week, this month, last month, custom.
void showDateRangeFilterSheet({
  required BuildContext context,
  DateTime? currentFrom,
  DateTime? currentTo,
  required void Function(String label, DateTime from, DateTime to) onApply,
  required VoidCallback onClear,
}) {
  final now = DateTime.now();
  final fmtShort = DateFormat('M/d');

  // This week (Monday ~ Sunday)
  final weekday = now.weekday;
  final thisWeekStart = now.subtract(Duration(days: weekday - 1));
  final thisWeekEnd = thisWeekStart.add(const Duration(days: 6));
  // Last week
  final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
  final lastWeekEnd = thisWeekStart.subtract(const Duration(days: 1));

  void apply(String label, DateTime from, DateTime to) {
    Navigator.of(context).pop();
    onApply(label, from, to);
  }

  showModalBottomSheet(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            context.bbSpace.gapV(BbSpaceToken.lg),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.xxl),
            Text(
              '기간 필터',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            context.bbSpace.gapV(BbSpaceToken.lg),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('이번 주'),
              subtitle: Text(
                  '${fmtShort.format(thisWeekStart)} ~ ${fmtShort.format(thisWeekEnd)}'),
              onTap: () => apply('이번 주', thisWeekStart, thisWeekEnd),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('지난 주'),
              subtitle: Text(
                  '${fmtShort.format(lastWeekStart)} ~ ${fmtShort.format(lastWeekEnd)}'),
              onTap: () => apply('지난 주', lastWeekStart, lastWeekEnd),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('이번 달'),
              subtitle: Text('${now.month}월'),
              onTap: () {
                final monthStart = DateTime(now.year, now.month, 1);
                final monthEnd = DateTime(now.year, now.month + 1, 0);
                apply('이번 달', monthStart, monthEnd);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('지난 달'),
              onTap: () {
                final prevMonth = DateTime(now.year, now.month - 1, 1);
                final prevMonthEnd = DateTime(now.year, now.month, 0);
                apply('지난 달', prevMonth, prevMonthEnd);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('직접 설정'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange:
                      currentFrom != null && currentTo != null
                          ? DateTimeRange(
                              start: currentFrom,
                              end: currentTo,
                            )
                          : null,
                  locale: const Locale('ko'),
                );
                if (range != null && context.mounted) {
                  final label =
                      '${fmtShort.format(range.start)} ~ ${fmtShort.format(range.end)}';
                  onApply(label, range.start, range.end);
                }
              },
            ),
            if (currentFrom != null) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.clear,
                    color: Theme.of(context).colorScheme.error),
                title: Text('기간 필터 해제',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onClear();
                },
              ),
            ],
            context.bbSpace.gapV(BbSpaceToken.xxl),
          ],
        ),
        ),
      );
    },
  );
}

/// A date range indicator bar showing the active range label with a clear button.
class DateRangeIndicator extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const DateRangeIndicator({
    super.key,
    required this.label,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      // ★세로는 호스트가 갖는다. 가로만 남긴다.
      margin: EdgeInsets.symmetric(horizontal: context.bbSpace.xxl),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range,
              size: 16, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            child: Icon(Icons.close,
                size: 18, color: theme.colorScheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}
