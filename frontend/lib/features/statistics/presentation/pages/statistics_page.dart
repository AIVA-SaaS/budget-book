import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_state.dart';
import 'package:budget_book/features/statistics/presentation/widgets/summary_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/category_breakdown_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/monthly_trend_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/year_comparison_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/payment_method_stats_tab.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('통계'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '요약'),
              Tab(text: '카테고리별'),
              Tab(text: '추이'),
              Tab(text: '전년 비교'),
              Tab(text: '결제수단별'),
            ],
          ),
        ),
        body: BlocBuilder<StatisticsBloc, StatisticsState>(
          builder: (context, state) {
            return Column(
              children: [
                // Month navigator (hidden when date range is active)
                if (!state.hasDateRange)
                  MonthNavigator(
                    year: state.year,
                    month: state.month,
                    onMonthChanged: (m) {
                      final bloc = context.read<StatisticsBloc>();
                      bloc.add(LoadAllStatistics(year: m.year, month: m.month));
                      bloc.add(LoadYearComparison(year: m.year, month: m.month));
                      bloc.add(LoadPaymentMethodStats(year: m.year, month: m.month));
                    },
                  ),
                // Date range indicator (shown when active)
                if (state.hasDateRange)
                  _DateRangeIndicator(
                    label: state.dateRangeLabel ?? '',
                    onClear: () {
                      context.read<StatisticsBloc>().add(const ClearDateRangeFilter());
                    },
                  ),
                // Filter row: visibility + date range button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'ALL', label: Text('전체')),
                            ButtonSegment(value: 'SHARED', label: Text('공유')),
                            ButtonSegment(value: 'PRIVATE', label: Text('개인')),
                          ],
                          selected: {state.visibilityFilter},
                          onSelectionChanged: (value) {
                            context.read<StatisticsBloc>().add(
                                  ChangeVisibilityFilter(value.first),
                                );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DateRangeButton(
                        hasActiveRange: state.hasDateRange,
                        onPressed: () => _showDateRangeFilter(context, state),
                      ),
                    ],
                  ),
                ),
                // Tab views
                Expanded(
                  child: TabBarView(
                    children: [
                      SummaryTab(
                        summary: state.summary,
                        isLoading: state.summaryLoading,
                        error: state.summaryError,
                      ),
                      CategoryBreakdownTab(
                        categoryStats: state.categoryStats,
                        isLoading: state.categoryLoading,
                        error: state.categoryError,
                        selectedType: state.categoryType,
                        year: state.year,
                        month: state.month,
                        onTypeChanged: (type) {
                          context.read<StatisticsBloc>().add(
                                LoadCategoryBreakdown(
                                  year: state.year,
                                  month: state.month,
                                  type: type,
                                ),
                              );
                        },
                      ),
                      MonthlyTrendTab(
                        trends: state.trends,
                        isLoading: state.trendLoading,
                        error: state.trendError,
                      ),
                      YearComparisonTab(
                        currentYear: state.currentYearSummary,
                        previousYear: state.previousYearSummary,
                        isLoading: state.comparisonLoading,
                        error: state.comparisonError,
                        year: state.year,
                        month: state.month,
                      ),
                      PaymentMethodStatsTab(
                        stats: state.paymentMethodStats,
                        isLoading: state.paymentMethodLoading,
                        error: state.paymentMethodError,
                        year: state.year,
                        month: state.month,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showDateRangeFilter(BuildContext context, StatisticsState state) {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    final fmtShort = DateFormat('M/d');

    // This week
    final weekday = now.weekday;
    final thisWeekStart = now.subtract(Duration(days: weekday - 1));
    final thisWeekEnd = thisWeekStart.add(const Duration(days: 6));
    // Last week
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekStart.subtract(const Duration(days: 1));

    void applyFilter(String label, String from, String to) {
      Navigator.of(context).pop();
      context.read<StatisticsBloc>().add(SetDateRangeFilter(
            dateFrom: from,
            dateTo: to,
            label: label,
          ));
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                '기간 필터',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('이번 주'),
                subtitle: Text('${fmtShort.format(thisWeekStart)} ~ ${fmtShort.format(thisWeekEnd)}'),
                onTap: () => applyFilter(
                    '이번 주', fmt.format(thisWeekStart), fmt.format(thisWeekEnd)),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('지난 주'),
                subtitle: Text('${fmtShort.format(lastWeekStart)} ~ ${fmtShort.format(lastWeekEnd)}'),
                onTap: () => applyFilter(
                    '지난 주', fmt.format(lastWeekStart), fmt.format(lastWeekEnd)),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('이번 달'),
                subtitle: Text('${now.month}월'),
                onTap: () {
                  final monthStart = DateTime(now.year, now.month, 1);
                  final monthEnd = DateTime(now.year, now.month + 1, 0);
                  applyFilter('이번 달', fmt.format(monthStart), fmt.format(monthEnd));
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('지난 달'),
                onTap: () {
                  final prevMonth = DateTime(now.year, now.month - 1, 1);
                  final prevMonthEnd = DateTime(now.year, now.month, 0);
                  applyFilter('지난 달', fmt.format(prevMonth), fmt.format(prevMonthEnd));
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
                    initialDateRange: state.dateFrom != null && state.dateTo != null
                        ? DateTimeRange(
                            start: DateTime.parse(state.dateFrom!),
                            end: DateTime.parse(state.dateTo!),
                          )
                        : null,
                    locale: const Locale('ko'),
                  );
                  if (range != null && context.mounted) {
                    final label =
                        '${fmtShort.format(range.start)} ~ ${fmtShort.format(range.end)}';
                    context.read<StatisticsBloc>().add(SetDateRangeFilter(
                          dateFrom: fmt.format(range.start),
                          dateTo: fmt.format(range.end),
                          label: label,
                        ));
                  }
                },
              ),
              if (state.hasDateRange) ...[
                const Divider(),
                ListTile(
                  leading: Icon(Icons.clear, color: Theme.of(context).colorScheme.error),
                  title: Text('기간 필터 해제',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.read<StatisticsBloc>().add(const ClearDateRangeFilter());
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  final bool hasActiveRange;
  final VoidCallback onPressed;

  const _DateRangeButton({
    required this.hasActiveRange,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.date_range,
        color: hasActiveRange
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      tooltip: '기간 필터',
      onPressed: onPressed,
    );
  }
}

class _DateRangeIndicator extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _DateRangeIndicator({
    required this.label,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
