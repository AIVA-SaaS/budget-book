import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/core/widgets/filters/date_range_filter.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_state.dart';
import 'package:budget_book/features/statistics/presentation/widgets/summary_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/category_breakdown_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/monthly_trend_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/year_comparison_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/payment_method_stats_tab.dart';
import 'package:budget_book/core/utils/couple_mode.dart';

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
                  DateRangeIndicator(
                    label: state.dateRangeLabel ?? '',
                    onClear: () {
                      context.read<StatisticsBloc>().add(const ClearDateRangeFilter());
                    },
                  ),
                // Filter row: visibility (couple mode only) + date range button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      if (isCoupleMode())
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
                      if (!isCoupleMode()) const Spacer(),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.date_range,
                          color: state.hasDateRange
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        tooltip: '기간 필터',
                        onPressed: () => showDateRangeFilterSheet(
                          context: context,
                          currentFrom: state.dateFrom != null
                              ? DateTime.parse(state.dateFrom!)
                              : null,
                          currentTo: state.dateTo != null
                              ? DateTime.parse(state.dateTo!)
                              : null,
                          onApply: (label, from, to) {
                            final fmt = DateFormat('yyyy-MM-dd');
                            context.read<StatisticsBloc>().add(SetDateRangeFilter(
                                  dateFrom: fmt.format(from),
                                  dateTo: fmt.format(to),
                                  label: label,
                                ));
                          },
                          onClear: () {
                            context.read<StatisticsBloc>().add(const ClearDateRangeFilter());
                          },
                        ),
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

}
