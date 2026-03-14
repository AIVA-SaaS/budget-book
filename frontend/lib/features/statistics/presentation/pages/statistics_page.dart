import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_state.dart';
import 'package:budget_book/features/statistics/presentation/widgets/summary_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/category_breakdown_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/monthly_trend_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/year_comparison_tab.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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
            ],
          ),
        ),
        body: BlocBuilder<StatisticsBloc, StatisticsState>(
          builder: (context, state) {
            return Column(
              children: [
                // Month navigator
                _MonthNavigator(year: state.year, month: state.month),
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

class _MonthNavigator extends StatelessWidget {
  final int year;
  final int month;

  const _MonthNavigator({required this.year, required this.month});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy년 M월').format(DateTime(year, month));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = month == 1
                  ? DateTime(year - 1, 12)
                  : DateTime(year, month - 1);
              _loadAll(context, prev.year, prev.month);
            },
            tooltip: '이전 달',
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(year, month),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030, 12, 31),
              );
              if (picked != null && context.mounted) {
                _loadAll(context, picked.year, picked.month);
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
                  ? DateTime(year + 1, 1)
                  : DateTime(year, month + 1);
              _loadAll(context, next.year, next.month);
            },
            tooltip: '다음 달',
          ),
        ],
      ),
    );
  }

  void _loadAll(BuildContext context, int year, int month) {
    final bloc = context.read<StatisticsBloc>();
    bloc.add(LoadAllStatistics(year: year, month: month));
    bloc.add(LoadYearComparison(year: year, month: month));
  }
}
