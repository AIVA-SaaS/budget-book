import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/bb_tab.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/core/widgets/filters/date_range_filter.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_state.dart';
import 'package:budget_book/features/statistics/presentation/widgets/category_breakdown_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/monthly_trend_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/year_comparison_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/payment_method_stats_tab.dart';
import 'package:budget_book/core/utils/couple_mode.dart';

class StatisticsPage extends StatelessWidget {
  /// Phase 25 Step 11 — 분석 탭 wrapper 에서는 false. 자체 진입(/statistics) 시 true.
  final bool showAppBar;

  /// 회차 12 follow-up (2026-05-04) — 분석 탭 wrapper 가 부모 단일 MonthNavigator
  /// 표시. 이 페이지의 자체 MonthNavigator hide.
  final bool showMonthNavigator;

  const StatisticsPage({
    super.key,
    this.showAppBar = true,
    this.showMonthNavigator = true,
  });

  @override
  Widget build(BuildContext context) {
    // 4개 sub-tab. 요약은 다른 항목들과 중복되어 제거 (사용자 요청).
    // 순서는 기존 TabBarView children 과 맞춤 (카테고리 → 추이 → 전년비교 → 결제수단).
    final tabs = [
      bbTab(context, icon: Icons.pie_chart_outline, label: '카테고리별'),
      bbTab(context, icon: Icons.show_chart, label: '추이'),
      bbTab(context, icon: Icons.compare_arrows, label: '전년 비교'),
      bbTab(context, icon: Icons.credit_card, label: '결제수단별'),
    ];
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        // showAppBar=false (분석 탭 wrapper) 시에도 PreferredSize 안 쓰고
        // 단일 AppBar 의 toolbarHeight 만 0 으로 — nested TabController 충돌 회피.
        appBar: AppBar(
          toolbarHeight: showAppBar ? kToolbarHeight : 0,
          automaticallyImplyLeading: showAppBar,
          title: showAppBar ? const Text('통계') : null,
          actions: showAppBar
              ? [
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined),
                    tooltip: '기간별 상세 분석',
                    onPressed: () => context.push('/period-summary'),
                  ),
                ]
              : null,
          bottom: TabBar(isScrollable: true, tabs: tabs),
        ),
        body: BlocBuilder<StatisticsBloc, StatisticsState>(
          builder: (context, state) {
            return Column(
              children: [
                // Month navigator (hidden when date range is active)
                // 회차 12 follow-up — 분석 탭 wrapper 시 부모 단일 표시 (hide).
                if (showMonthNavigator && !state.hasDateRange)
                  // MonthNavigator는 MonthCubit.state를 자동 watch
                  const MonthNavigator(),
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
