import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/core/widgets/filters/unified_filter_bar.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_state.dart';
import 'package:budget_book/features/statistics/presentation/widgets/period_category_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/period_budget_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/period_payment_method_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/period_daily_tab.dart';

class PeriodSummaryPage extends StatefulWidget {
  const PeriodSummaryPage({super.key});

  @override
  State<PeriodSummaryPage> createState() => _PeriodSummaryPageState();
}

class _PeriodSummaryPageState extends State<PeriodSummaryPage> {
  late UnifiedFilterState _filterState;
  final _fmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    _filterState = UnifiedFilterState(
      dateFrom: firstDay,
      dateTo: now,
      dateRangeLabel: '${now.month}월',
    );
    _loadData();
  }

  void _loadData() {
    if (_filterState.dateFrom != null && _filterState.dateTo != null) {
      context.read<PeriodSummaryBloc>().add(LoadPeriodSummary(
            dateFrom: _fmt.format(_filterState.dateFrom!),
            dateTo: _fmt.format(_filterState.dateTo!),
            categoryId: _filterState.categoryIds.isNotEmpty ? _filterState.categoryIds.first : null,
            paymentMethodId: _filterState.paymentMethodIds.isNotEmpty ? _filterState.paymentMethodIds.first : null,
          ));
    }
  }

  void _onFilterChanged(UnifiedFilterState newState) {
    setState(() => _filterState = newState);
    if (newState.dateFrom != null && newState.dateTo != null) {
      context.read<PeriodSummaryBloc>().add(LoadPeriodSummary(
            dateFrom: _fmt.format(newState.dateFrom!),
            dateTo: _fmt.format(newState.dateTo!),
            categoryId: newState.categoryIds.isNotEmpty ? newState.categoryIds.first : null,
            paymentMethodId: newState.paymentMethodIds.isNotEmpty ? newState.paymentMethodIds.first : null,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('기간별 기록'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '카테고리별'),
              Tab(text: '예산별'),
              Tab(text: '결제수단별'),
              Tab(text: '일별'),
            ],
          ),
        ),
        body: Column(
          children: [
            UnifiedFilterBar(
              enabledFilters: const {
                FilterType.dateRange,
                FilterType.category,
                FilterType.paymentMethod,
              },
              state: _filterState,
              onFilterChanged: _onFilterChanged,
            ),
            _buildSummaryCards(),
            Expanded(
              child: BlocBuilder<PeriodSummaryBloc, PeriodSummaryState>(
                builder: (context, state) {
                  if (state is PeriodSummaryLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is PeriodSummaryError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(state.message, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state is PeriodSummaryLoaded) {
                    final summary = state.summary;
                    return TabBarView(
                      children: [
                        PeriodCategoryTab(items: summary.byCategory),
                        PeriodBudgetTab(items: summary.byBudget),
                        PeriodPaymentMethodTab(
                            items: summary.byPaymentMethod),
                        PeriodDailyTab(items: summary.byDate),
                      ],
                    );
                  }
                  // Initial state
                  return const Center(
                    child: Text('기간을 선택하면 데이터가 표시됩니다'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return BlocBuilder<PeriodSummaryBloc, PeriodSummaryState>(
      builder: (context, state) {
        int income = 0;
        int expense = 0;
        int balance = 0;

        if (state is PeriodSummaryLoaded) {
          income = state.summary.totalIncome;
          expense = state.summary.totalExpense;
          balance = state.summary.balance;
        }

        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: '수입',
                  amount: income,
                  color: Colors.blue,
                  isLoading: state is PeriodSummaryLoading,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: '지출',
                  amount: expense,
                  color: cs.error,
                  isLoading: state is PeriodSummaryLoading,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: '잔액',
                  amount: balance,
                  color: balance >= 0 ? Colors.green : cs.error,
                  isLoading: state is PeriodSummaryLoading,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final bool isLoading;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    )),
            const SizedBox(height: 4),
            isLoading
                ? const SizedBox(
                    height: 16,
                    width: 60,
                    child: LinearProgressIndicator(),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${CurrencyFormatter.format(amount)}원',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
