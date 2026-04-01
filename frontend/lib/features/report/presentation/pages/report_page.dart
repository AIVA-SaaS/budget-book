import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/features/report/domain/entities/weekly_report.dart';
import 'package:budget_book/features/report/domain/entities/monthly_report.dart';
import 'package:budget_book/features/report/presentation/bloc/report_bloc.dart';
import 'package:budget_book/features/report/presentation/bloc/report_event.dart';
import 'package:budget_book/features/report/presentation/bloc/report_state.dart';
import 'package:budget_book/features/report/presentation/widgets/overspend_category_tile.dart';
import 'package:budget_book/features/report/presentation/widgets/daily_spending_chart.dart';
import 'package:budget_book/features/report/presentation/widgets/month_comparison_card.dart';
import 'package:budget_book/core/widgets/error_widget.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late int _year;
  late int _month;

  static int _currentWeekOfMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    return ((date.day + firstDay.weekday - 2) ~/ 7) + 1;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _changeMonth(int year, int month) {
    setState(() {
      _year = year;
      _month = month;
    });
    final now = DateTime.now();
    final week = (year == now.year && month == now.month)
        ? _currentWeekOfMonth(now)
        : 1;
    context.read<ReportBloc>()
      ..add(LoadMonthlyReport(year: year, month: month))
      ..add(LoadWeeklyReport(year: year, month: month, week: week));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('리포트'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '주간 리포트'),
              Tab(text: '월간 리포트'),
            ],
          ),
        ),
        body: Column(
          children: [
            MonthNavigator(
              year: _year,
              month: _month,
              onMonthChanged: (m) => _changeMonth(m.year, m.month),
            ),
            Expanded(
              child: BlocBuilder<ReportBloc, ReportState>(
                builder: (context, state) {
                  return switch (state) {
                    ReportInitial() ||
                    ReportLoading() =>
                      const Center(child: CircularProgressIndicator()),
                    ReportLoaded(
                      weeklyReport: final weekly,
                      monthlyReport: final monthly,
                    ) =>
                      TabBarView(
                        children: [
                          weekly != null
                              ? _buildWeeklyTab(context, weekly)
                              : _buildEmptyTab(context, '주간 리포트가 없습니다'),
                          monthly != null
                              ? _buildMonthlyTab(context, monthly)
                              : _buildEmptyTab(context, '월간 리포트가 없습니다'),
                        ],
                      ),
                    ReportError(message: final message) =>
                      _buildError(context, message),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTab(BuildContext context, WeeklyReport report) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');
    final statusColor = report.isOver ? Colors.red : Colors.green;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Budget vs Spent summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.weekNumber}주차 (${report.weekStart} ~ ${report.weekEnd})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAmountColumn(
                        context,
                        label: '예산',
                        amount: report.totalBudget,
                        color: theme.colorScheme.primary,
                        numberFormat: numberFormat,
                      ),
                    ),
                    Expanded(
                      child: _buildAmountColumn(
                        context,
                        label: '지출',
                        amount: report.totalSpent,
                        color: statusColor,
                        numberFormat: numberFormat,
                      ),
                    ),
                    Expanded(
                      child: _buildAmountColumn(
                        context,
                        label: report.remainingAmount >= 0 ? '남은 금액' : '초과 금액',
                        amount: report.remainingAmount.abs(),
                        color: statusColor,
                        numberFormat: numberFormat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (report.usageRate / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${report.usageRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Top overspend categories
        if (report.topOverspendCategories.isNotEmpty) ...[
          Text(
            '과소비 카테고리',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: report.topOverspendCategories
                  .map((c) => OverspendCategoryTile(category: c))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Daily spending chart
        if (report.dailySpending.isNotEmpty)
          DailySpendingChart(
            dailySpending: report.dailySpending,
            peakSpendingDay: report.peakSpendingDay,
          ),
      ],
    );
  }

  Widget _buildMonthlyTab(BuildContext context, MonthlyReport report) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Income / Expense / Balance summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.yearMonth} 요약',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAmountColumn(
                        context,
                        label: '수입',
                        amount: report.totalIncome,
                        color: Colors.blue,
                        numberFormat: numberFormat,
                      ),
                    ),
                    Expanded(
                      child: _buildAmountColumn(
                        context,
                        label: '지출',
                        amount: report.totalExpense,
                        color: Colors.red,
                        numberFormat: numberFormat,
                      ),
                    ),
                    Expanded(
                      child: _buildAmountColumn(
                        context,
                        label: '잔액',
                        amount: report.balance,
                        color: report.balance >= 0 ? Colors.green : Colors.red,
                        numberFormat: numberFormat,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Group summaries
        if (report.groupSummaries.isNotEmpty) ...[
          Text(
            '그룹별 예산',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: report.groupSummaries
                  .map((g) => _buildGroupTile(context, g, numberFormat))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Top categories
        if (report.topCategories.isNotEmpty) ...[
          Text(
            '주요 지출 카테고리',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: report.topCategories.map((c) {
                return ListTile(
                  title: Text(c.categoryName),
                  subtitle: Text(
                    '평균 ${numberFormat.format(c.averageAmount)}원 (${c.transactionCount}건)',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${numberFormat.format(c.amount)}원',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (c.deviation != 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              c.deviation > 0
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 12,
                              color:
                                  c.deviation > 0 ? Colors.red : Colors.green,
                            ),
                            Text(
                              '${numberFormat.format(c.deviation.abs())}원',
                              style: TextStyle(
                                fontSize: 11,
                                color: c.deviation > 0
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Month comparison
        if (report.previousMonthComparison != null) ...[
          MonthComparisonCard(comparison: report.previousMonthComparison!),
          const SizedBox(height: 16),
        ],
        // Card pending badge
        if (report.cardPendingSummary != null) ...[
          Card(
            color: Colors.orange.withValues(alpha: 0.05),
            child: ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.orange),
              title: const Text('카드 미결제 금액'),
              subtitle: Text('${report.cardPendingSummary!.cardCount}개 카드'),
              trailing: Text(
                '${numberFormat.format(report.cardPendingSummary!.totalPendingAmount)}원',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.orange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Day of week heatmap
        if (report.dayOfWeekPattern.isNotEmpty) ...[
          _buildDayOfWeekHeatmap(context, report, numberFormat),
        ],
      ],
    );
  }

  Widget _buildAmountColumn(
    BuildContext context, {
    required String label,
    required int amount,
    required Color color,
    required NumberFormat numberFormat,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${numberFormat.format(amount)}원',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupTile(
      BuildContext context, GroupSummary group, NumberFormat numberFormat) {
    final progress = (group.usageRate / 100).clamp(0.0, 1.0);
    final statusColor = group.usageRate > 100
        ? Colors.red
        : group.usageRate > 80
            ? Colors.orange
            : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(group.groupName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      group.budgetType == 'WEEKLY' ? '주간' : '월간',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              Text(
                '${group.usageRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${numberFormat.format(group.totalSpent)}원 / ${numberFormat.format(group.totalBudget)}원',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDayOfWeekHeatmap(
      BuildContext context, MonthlyReport report, NumberFormat numberFormat) {
    final theme = Theme.of(context);
    final maxSpending = report.dayOfWeekPattern
        .map((d) => d.averageSpending)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '요일별 소비 패턴',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: report.dayOfWeekPattern.map((day) {
                final intensity =
                    maxSpending > 0 ? day.averageSpending / maxSpending : 0.0;
                return Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.1 + intensity * 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _dayOfWeekLabel(day.dayOfWeek),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: intensity > 0.5
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      numberFormat.format(day.averageSpending),
                      style: const TextStyle(fontSize: 9),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTab(BuildContext context, String message) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return AppErrorWidget(
      message: message,
      onRetry: () {
        final now = DateTime.now();
        context.read<ReportBloc>()
          ..add(LoadMonthlyReport(year: now.year, month: now.month))
          ..add(LoadWeeklyReport(
              year: now.year,
              month: now.month,
              week: _currentWeekOfMonth(now)));
      },
      showHomeButton: true,
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
