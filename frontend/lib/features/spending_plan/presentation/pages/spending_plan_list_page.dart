import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_bloc.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_event.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_state.dart';
import 'package:budget_book/features/spending_plan/presentation/widgets/spending_plan_card.dart';
import 'package:budget_book/features/spending_plan/presentation/widgets/spending_plan_summary_card.dart';

class SpendingPlanListPage extends StatefulWidget {
  const SpendingPlanListPage({super.key});

  @override
  State<SpendingPlanListPage> createState() => _SpendingPlanListPageState();
}

class _SpendingPlanListPageState extends State<SpendingPlanListPage> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  String? _statusFilter;

  static const _filterOptions = <(String?, String)>[
    (null, '전체'),
    ('PLANNED', '계획됨'),
    ('COMPLETED', '완료'),
    ('SKIPPED', '건너뜀'),
    ('OVERDUE', '기한초과'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  void _loadPlans() {
    final startDate = DateFormat('yyyy-MM-dd')
        .format(DateTime(_year, _month, 1));
    final endDate = DateFormat('yyyy-MM-dd')
        .format(DateTime(_year, _month + 1, 0));
    context.read<SpendingPlanBloc>().add(LoadSpendingPlans(
          startDate: startDate,
          endDate: endDate,
          status: _statusFilter,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지출 계획'),
      ),
      body: Column(
        children: [
          // Month navigator
          MonthNavigator(
            year: _year,
            month: _month,
            onMonthChanged: (val) {
              setState(() {
                _year = val.year;
                _month = val.month;
              });
              _loadPlans();
            },
          ),
          // Filter chips
          _buildFilterChips(),
          // Content
          Expanded(
            child: BlocConsumer<SpendingPlanBloc, SpendingPlanState>(
              listener: _onStateChange,
              builder: (context, state) {
                return switch (state) {
                  SpendingPlanInitial() || SpendingPlanLoading() =>
                    const SkeletonLoader(itemCount: 5),
                  SpendingPlanLoaded() => _buildLoaded(context, state),
                  SpendingPlanError() => _buildError(context),
                };
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/spending-plans/create'),
        tooltip: '계획 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _onStateChange(BuildContext context, SpendingPlanState state) {
    if (state is SpendingPlanError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else if (state is SpendingPlanLoaded && state.operationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.operationError!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else if (state is SpendingPlanLoaded &&
        state.operationSuccess != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.operationSuccess!)),
      );
    }
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = _filterOptions[index];
          final isSelected = _statusFilter == value;
          return FilterChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _statusFilter = isSelected ? null : value);
              _loadPlans();
            },
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, SpendingPlanLoaded state) {
    return Column(
      children: [
        // Summary card
        SpendingPlanSummaryCard(summary: state.summary),
        const Divider(height: 1),
        // Timeline grouped by date
        Expanded(
          child: state.plans.isEmpty
              ? _buildEmpty(context)
              : _buildTimeline(context, state),
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context, SpendingPlanLoaded state) {
    final grouped = state.groupedByDate;
    final dates = grouped.keys.toList();

    return ListView.builder(
      key: const PageStorageKey('spending_plan_list'),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final dateStr = dates[index];
        final plans = grouped[dateStr]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(dateStr: dateStr),
            ...plans.map((plan) => SpendingPlanCard(
                  plan: plan,
                  onTap: () =>
                      context.push('/spending-plans/edit/${plan.id}'),
                  onComplete: () => _showCompleteDialog(context, plan),
                  onSkip: () => _confirmSkip(context, plan),
                  onDelete: () => _confirmDelete(context, plan),
                )),
          ],
        );
      },
    );
  }

  void _showCompleteDialog(BuildContext context, SpendingPlan plan) {
    final amountController = TextEditingController(
      text: '${plan.amount}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계획 완료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\'${plan.name}\'을(를) 완료 처리합니다.'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: '실제 사용 금액',
                suffixText: '원',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final actualAmount = int.tryParse(
                  amountController.text.replaceAll(',', ''));
              context.read<SpendingPlanBloc>().add(CompletePlan(
                    id: plan.id,
                    actualAmount: actualAmount,
                  ));
            },
            child: const Text('완료'),
          ),
        ],
      ),
    );
    // Dispose controller after dialog closes
    amountController.dispose();
  }

  void _confirmSkip(BuildContext context, SpendingPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계획 건너뛰기'),
        content: Text('\'${plan.name}\'을(를) 건너뛰시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<SpendingPlanBloc>().add(SkipPlan(plan.id));
            },
            child: const Text('건너뛰기'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SpendingPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계획 삭제'),
        content: Text('\'${plan.name}\'을(를) 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context
                  .read<SpendingPlanBloc>()
                  .add(DeleteSpendingPlan(plan.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.event_note_outlined,
      title: '등록된 계획이 없습니다',
      subtitle: '지출 계획을 등록하고 예산 사용을 관리하세요',
      actionLabel: '계획 추가',
      onAction: () => context.push('/spending-plans/create'),
    );
  }

  Widget _buildError(BuildContext context) {
    return AppErrorWidget(
      message: '지출 계획을 불러오지 못했습니다',
      onRetry: _loadPlans,
      showHomeButton: true,
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String dateStr;

  const _DateHeader({required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(dateStr);
    String displayText;
    if (date != null) {
      final weekday = DateFormat.E('ko').format(date);
      displayText =
          '${date.month}월 ${date.day}일 ($weekday)';
    } else {
      displayText = dateStr;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.calendar_today,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Text(
            displayText,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
