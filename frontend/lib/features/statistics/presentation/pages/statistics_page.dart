import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                // Month navigator
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
                // Visibility filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

