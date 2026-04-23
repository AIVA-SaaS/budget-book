import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/budget/presentation/widgets/budget_summary_card.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_state.dart';

/// Phase 23 PR-X7: 분석 탭 — 예산 진행 + 통계 차트 병합(수직 스크롤).
///
/// 구성:
///   - 상단 chip row: `[월별] [주별] [연별]` (local state, 기본 월별)
///   - 섹션 1: 예산 진행 카드 (BudgetBloc.summary 재사용)
///   - 섹션 2: 카테고리별 지출 파이 + 예산 있는 카테고리 bar overlay
///   - 섹션 3: 월별 비교 bar (수입·지출)
///   - 섹션 4: 결제수단별 분포 도넛
///   - 하단 버튼: 예산 편집 → `/budgets/create`
///
/// Data 재사용 전략: BudgetBloc / StatisticsBloc 기존 상태를 그대로 읽어 **중복 쿼리 없음**.
/// 페이지 진입 시 두 BLoC 이 아직 로드되지 않았다면 초기 이벤트 dispatch.
enum AnalysisPeriod { monthly, weekly, yearly }

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  AnalysisPeriod _period = AnalysisPeriod.monthly;

  static const _pieColors = [
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

  @override
  void initState() {
    super.initState();
    // Dispatch initial loads if data missing. MonthCubit drives year/month.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final month = context.read<MonthCubit>().state;
      final budgetBloc = context.read<BudgetBloc>();
      if (budgetBloc.state is BudgetInitial) {
        budgetBloc.add(LoadBudgets(year: month.year, month: month.month));
      }
      final statsBloc = context.read<StatisticsBloc>();
      statsBloc.add(LoadAllStatistics(year: month.year, month: month.month));
      statsBloc.add(
          LoadPaymentMethodStats(year: month.year, month: month.month));
    });
  }

  void _onPeriodChanged(AnalysisPeriod period) {
    setState(() => _period = period);
    // 연별: 12 개월 추이 재로드. 월별/주별은 기본 6 개월.
    final months = period == AnalysisPeriod.yearly ? 12 : 6;
    context.read<StatisticsBloc>().add(LoadMonthlyTrend(months: months));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('분석'),
      ),
      body: Column(
        children: [
          const MonthNavigator(),
          _buildPeriodChipRow(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final month = context.read<MonthCubit>().state;
                context
                    .read<BudgetBloc>()
                    .add(LoadBudgets(year: month.year, month: month.month));
                context.read<StatisticsBloc>().add(
                    LoadAllStatistics(year: month.year, month: month.month));
                context.read<StatisticsBloc>().add(LoadPaymentMethodStats(
                    year: month.year, month: month.month));
              },
              child: ListView(
                key: const PageStorageKey('analysis_scroll'),
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  // Section 1: 예산 진행
                  _buildBudgetSection(context),
                  const SizedBox(height: 8),
                  // Section 2: 카테고리별 지출 파이 + 예산 bar overlay
                  _buildCategoryBreakdownSection(context),
                  const SizedBox(height: 8),
                  // Section 3: 월별 비교 bar
                  _buildMonthlyComparisonSection(context),
                  const SizedBox(height: 8),
                  // Section 4: 결제수단별 분포 도넛
                  _buildPaymentMethodSection(context),
                  const SizedBox(height: 16),
                  // 예산 편집 버튼
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      key: const Key('analysis_edit_budget_button'),
                      onPressed: () {
                        final month = context.read<MonthCubit>().state;
                        context.push(
                            '/budgets/create?year=${month.year}&month=${month.month}');
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('예산 편집'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChipRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<AnalysisPeriod>(
        segments: const [
          ButtonSegment(
            value: AnalysisPeriod.monthly,
            label: Text('월별'),
          ),
          ButtonSegment(
            value: AnalysisPeriod.weekly,
            label: Text('주별'),
          ),
          ButtonSegment(
            value: AnalysisPeriod.yearly,
            label: Text('연별'),
          ),
        ],
        selected: {_period},
        onSelectionChanged: (set) => _onPeriodChanged(set.first),
      ),
    );
  }

  // Section 1: 예산 진행 카드
  Widget _buildBudgetSection(BuildContext context) {
    return BlocBuilder<BudgetBloc, BudgetState>(
      builder: (context, state) {
        if (state is BudgetLoading || state is BudgetInitial) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is BudgetError) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('예산 불러오기 실패: ${state.message}'),
            ),
          );
        }
        if (state is BudgetLoaded) {
          final summary = state.summary;
          if (summary == null || summary.totalBudget == 0) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이번 달 예산',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '설정된 예산이 없습니다. "예산 편집" 을 눌러 시작하세요.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          // 초과 카테고리 pill 목록
          final overItems =
              summary.items.where((i) => i.isOverBudget).toList();

          return Column(
            children: [
              BudgetSummaryCard(summary: summary),
              if (overItems.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: overItems
                          .map((item) => Chip(
                                key: ValueKey(
                                    'over_${item.category?.id ?? item.groupId ?? "total"}'),
                                label: Text(
                                  '${item.category?.name ?? item.groupName ?? '전체'} 초과',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                avatar: const Icon(Icons.warning_amber_rounded,
                                    size: 16, color: Colors.white),
                                backgroundColor: Colors.red.shade400,
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                              ))
                          .toList(),
                    ),
                  ),
                ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // Section 2: 카테고리별 지출 파이 + 예산 bar overlay
  Widget _buildCategoryBreakdownSection(BuildContext context) {
    return BlocBuilder<StatisticsBloc, StatisticsState>(
      builder: (context, state) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('카테고리별 지출',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (state.categoryLoading)
                  const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()))
                else if (state.categoryError != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child:
                        Text('불러오기 실패: ${state.categoryError}'),
                  )
                else if (state.categoryStats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '이 달에 기록된 거래가 없습니다',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  )
                else
                  _buildCategoryPieWithBars(context, state.categoryStats),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryPieWithBars(
      BuildContext context, List<CategoryStatistics> stats) {
    final sorted = stats.toList()..sort((a, b) => b.amount.compareTo(a.amount));

    // 예산 overlay: BudgetBloc 상태에서 카테고리별 budgetAmount 조회
    final budgetState = context.read<BudgetBloc>().state;
    final budgetItems = budgetState is BudgetLoaded
        ? budgetState.summary?.items ?? const <BudgetSummaryItem>[]
        : const <BudgetSummaryItem>[];
    int? budgetForCategory(String? categoryId) {
      if (categoryId == null) return null;
      for (final b in budgetItems) {
        if (b.category?.id == categoryId) return b.budgetAmount;
      }
      return null;
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sorted.asMap().entries.map((entry) {
                final idx = entry.key;
                final stat = entry.value;
                final color = UIHelpers.parseColor(
                  stat.category.color,
                  fallback: _pieColors[idx % _pieColors.length],
                );
                return PieChartSectionData(
                  value: stat.amount.toDouble(),
                  title: stat.percentage >= 5
                      ? '${stat.percentage.toStringAsFixed(0)}%'
                      : '',
                  color: color,
                  radius: 60,
                  titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              }).toList(),
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...sorted.asMap().entries.map((entry) {
          final idx = entry.key;
          final stat = entry.value;
          final color = UIHelpers.parseColor(
            stat.category.color,
            fallback: _pieColors[idx % _pieColors.length],
          );
          final budgetAmt = budgetForCategory(stat.category.id);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(stat.category.displayName,
                              style: Theme.of(context).textTheme.bodyMedium),
                          Text(
                            '${CurrencyFormatter.format(stat.amount)}원',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 예산 bar overlay (예산 있는 카테고리만)
                      if (budgetAmt != null && budgetAmt > 0)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (stat.amount / budgetAmt).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                stat.amount > budgetAmt
                                    ? Colors.red
                                    : color),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value:
                                (stat.percentage / 100).clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: color.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      if (budgetAmt != null && budgetAmt > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '예산 ${CurrencyFormatter.format(budgetAmt)}원',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Section 3: 월별 비교 bar (수입·지출, 이체는 BE trends 미포함이므로 수입/지출만)
  Widget _buildMonthlyComparisonSection(BuildContext context) {
    return BlocBuilder<StatisticsBloc, StatisticsState>(
      builder: (context, state) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('월별 비교',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (state.trendLoading)
                  const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()))
                else if (state.trendError != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('추이 로드 실패: ${state.trendError}'),
                  )
                else if (state.trends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '비교할 데이터가 없습니다',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  )
                else
                  _buildMonthlyBarChart(context, state.trends),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthlyBarChart(
      BuildContext context, List<MonthlyTrend> trends) {
    final maxValue = trends.fold<double>(
      0,
      (prev, t) {
        final local =
            [t.totalIncome, t.totalExpense].fold<int>(0, (a, b) => a > b ? a : b);
        return local > prev ? local.toDouble() : prev;
      },
    );
    final maxY = (maxValue / 10000).ceilToDouble();

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY > 0 ? maxY * 1.15 : 10,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}만',
                      style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trends.length) {
                    return const Text('');
                  }
                  final ym = trends[index].yearMonth;
                  final monthStr = ym.split('-').last;
                  return Text('${int.parse(monthStr)}월',
                      style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: trends.asMap().entries.map((entry) {
            final idx = entry.key;
            final t = entry.value;
            return BarChartGroupData(
              x: idx,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: t.totalIncome / 10000,
                  color: const Color(0xFF4CAF50),
                  width: 6,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(2)),
                ),
                BarChartRodData(
                  toY: t.totalExpense / 10000,
                  color: const Color(0xFFF44336),
                  width: 6,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(2)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // Section 4: 결제수단별 분포 도넛
  Widget _buildPaymentMethodSection(BuildContext context) {
    return BlocBuilder<StatisticsBloc, StatisticsState>(
      builder: (context, state) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('결제수단별 분포',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (state.paymentMethodLoading)
                  const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()))
                else if (state.paymentMethodError != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child:
                        Text('불러오기 실패: ${state.paymentMethodError}'),
                  )
                else if (state.paymentMethodStats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '이 달 결제수단 데이터가 없습니다',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  )
                else
                  _buildPaymentMethodDonut(context, state.paymentMethodStats),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodDonut(
      BuildContext context, List<PaymentMethodStatistics> stats) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: stats.asMap().entries.map((entry) {
                final idx = entry.key;
                final stat = entry.value;
                final color = _pieColors[idx % _pieColors.length];
                return PieChartSectionData(
                  value: stat.totalAmount.toDouble(),
                  title: stat.percentage >= 5
                      ? '${stat.percentage.toStringAsFixed(0)}%'
                      : '',
                  color: color,
                  radius: 55,
                  titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              }).toList(),
              centerSpaceRadius: 50,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...stats.asMap().entries.map((entry) {
          final idx = entry.key;
          final stat = entry.value;
          final color = _pieColors[idx % _pieColors.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(stat.paymentMethodName,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                Text('${CurrencyFormatter.format(stat.totalAmount)}원',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('${stat.percentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        )),
              ],
            ),
          );
        }),
      ],
    );
  }
}
