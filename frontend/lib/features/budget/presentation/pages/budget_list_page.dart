import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/budget/presentation/widgets/budget_summary_card.dart';
import 'package:budget_book/core/widgets/icon_picker.dart';
import 'package:budget_book/core/widgets/color_picker.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_bloc.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_event.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_state.dart';
import 'package:budget_book/features/weekly_budget/presentation/widgets/week_summary_card.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/current_week_summary.dart';

class BudgetListPage extends StatefulWidget {
  const BudgetListPage({super.key});

  @override
  State<BudgetListPage> createState() => _BudgetListPageState();
}

class _BudgetListPageState extends State<BudgetListPage> {
  bool _isWeeklyView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isWeeklyView ? '주간 예산' : '예산 관리'),
        actions: _isWeeklyView
            ? null
            : [
                IconButton(
                  onPressed: () {
                    final state = context.read<BudgetBloc>().state;
                    final year = state is BudgetLoaded
                        ? state.year
                        : DateTime.now().year;
                    final month = state is BudgetLoaded
                        ? state.month
                        : DateTime.now().month;

                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('전월 예산 복사'),
                        content: const Text(
                          '이전 달의 예산 설정을 현재 달로 복사하시겠습니까?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('취소'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              context.read<BudgetBloc>().add(
                                    CopyPreviousMonthBudgets(
                                      year: year,
                                      month: month,
                                    ),
                                  );
                            },
                            child: const Text('복사'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.content_copy),
                  tooltip: '전월 예산 복사',
                ),
                IconButton(
                  onPressed: () => context.push('/categories'),
                  icon: const Icon(Icons.category),
                  tooltip: '카테고리 관리',
                ),
              ],
      ),
      body: Column(
        children: [
          // View mode toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('월간')),
                ButtonSegment(value: true, label: Text('주간')),
              ],
              selected: {_isWeeklyView},
              onSelectionChanged: (value) {
                setState(() => _isWeeklyView = value.first);
                if (value.first) {
                  final now = DateTime.now();
                  getIt<WeeklyBudgetBloc>()
                    ..add(LoadWeeklyOverview(
                        year: now.year, month: now.month))
                    ..add(const LoadCurrentWeek());
                }
              },
            ),
          ),
          // Content
          Expanded(
            child: _isWeeklyView
                ? _buildWeeklyContent()
                : BlocConsumer<BudgetBloc, BudgetState>(
                    listener: (context, state) {
                      if (state is BudgetError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else if (state is BudgetLoaded &&
                          state.operationError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.operationError!),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else if (state is BudgetLoaded &&
                          state.operationSuccess != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.operationSuccess!),
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      return switch (state) {
                        BudgetInitial() || BudgetLoading() =>
                          const SkeletonLoader(itemCount: 5),
                        BudgetLoaded() => _buildLoaded(context, state),
                        BudgetError() => _buildError(context),
                      };
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _isWeeklyView
          ? null
          : FloatingActionButton(
              onPressed: () {
                final state = context.read<BudgetBloc>().state;
                final year =
                    state is BudgetLoaded ? state.year : DateTime.now().year;
                final month =
                    state is BudgetLoaded ? state.month : DateTime.now().month;
                context.push('/budgets/create?year=$year&month=$month');
              },
              tooltip: '예산 추가',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildWeeklyContent() {
    return BlocProvider<WeeklyBudgetBloc>.value(
      value: getIt<WeeklyBudgetBloc>(),
      child: BlocBuilder<WeeklyBudgetBloc, WeeklyBudgetState>(
        builder: (context, state) {
          return switch (state) {
            WeeklyBudgetInitial() || WeeklyBudgetLoading() =>
              const Center(child: CircularProgressIndicator()),
            WeeklyBudgetLoaded() => _buildWeeklyLoaded(context, state),
            WeeklyBudgetError(message: final message) => AppErrorWidget(
                message: message,
                onRetry: () {
                  final now = DateTime.now();
                  getIt<WeeklyBudgetBloc>()
                    ..add(LoadWeeklyOverview(
                        year: now.year, month: now.month))
                    ..add(const LoadCurrentWeek());
                },
                showHomeButton: true,
              ),
          };
        },
      ),
    );
  }

  Widget _buildWeeklyLoaded(BuildContext context, WeeklyBudgetLoaded state) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');

    return RefreshIndicator(
      onRefresh: () async {
        final now = DateTime.now();
        getIt<WeeklyBudgetBloc>()
          ..add(LoadWeeklyOverview(year: now.year, month: now.month))
          ..add(const LoadCurrentWeek());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current week hero card
          if (state.currentWeek != null) ...[
            _buildCurrentWeekHero(context, state.currentWeek!, numberFormat),
            const SizedBox(height: 24),
          ],
          // Weekly overview
          if (state.overview != null) ...[
            Text(
              '${state.overview!.yearMonth} 주간 예산',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...state.overview!.weeks.map((week) {
              final isCurrent = state.currentWeek != null &&
                  week.weekNumber == state.currentWeek!.weekNumber;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WeekSummaryCard(
                    weekSummary: week, isCurrentWeek: isCurrent),
              );
            }),
          ],
          if (state.overview == null && state.currentWeek == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 64,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '주간 예산 정보가 없습니다',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
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

  Widget _buildCurrentWeekHero(
    BuildContext context,
    CurrentWeekSummary currentWeek,
    NumberFormat numberFormat,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      color: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today,
                    color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  '이번 주 (${currentWeek.weekNumber}주차)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${currentWeek.weekStart} ~ ${currentWeek.weekEnd}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.7),
              ),
            ),
            if (currentWeek.groups.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...currentWeek.groups.map((group) {
                final progress = (group.usageRate / 100).clamp(0.0, 1.0);
                final statusColor = group.usageRate > 100
                    ? Colors.red
                    : group.usageRate > 80
                        ? Colors.orange
                        : Colors.green;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            group.groupName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            '${numberFormat.format(group.spentAmount)}원 / ${numberFormat.format(group.budgetAmount)}원',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
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
                          backgroundColor: theme
                              .colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.15),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, BudgetLoaded state) {
    return Column(
      children: [
        _MonthNavigator(year: state.year, month: state.month),
        if (state.summary != null)
          BudgetSummaryCard(summary: state.summary!),
        Expanded(
          child: state.budgets.isEmpty
              ? _buildEmpty(context)
              : _buildBudgetList(context, state),
        ),
      ],
    );
  }

  Widget _buildBudgetList(BuildContext context, BudgetLoaded state) {
    final numberFormat = NumberFormat('#,###');
    final summaryItems = state.summary?.items ?? [];

    return ListView.builder(
      itemCount: state.budgets.length,
      itemBuilder: (context, index) {
        final budget = state.budgets[index];
        final summaryItem = _findSummaryItem(summaryItems, budget);
        final usageRate = summaryItem?.usageRate ?? 0.0;
        final spentAmount = summaryItem?.spentAmount ?? 0;

        return Dismissible(
          key: Key(budget.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('예산 삭제'),
                content: Text(
                  '${budget.category?.name ?? "전체 예산"}을(를) 삭제하시겠습니까?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('삭제'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) {
            context.read<BudgetBloc>().add(DeleteBudget(budget.id));
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getCategoryColor(budget.category?.color),
              child: Icon(
                _getCategoryIcon(budget.category?.icon),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(budget.category?.name ?? '전체 예산'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (usageRate.clamp(0.0, 100.0)) / 100.0,
                    minHeight: 6,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    color: _getProgressColor(usageRate),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${numberFormat.format(spentAmount)}원 / ${numberFormat.format(budget.amount)}원 (${usageRate.toStringAsFixed(1)}%)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: Text(
              '${numberFormat.format(budget.amount)}원',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            onTap: () {
              final state = context.read<BudgetBloc>().state;
              final year =
                  state is BudgetLoaded ? state.year : DateTime.now().year;
              final month =
                  state is BudgetLoaded ? state.month : DateTime.now().month;
              context
                  .push('/budgets/edit/${budget.id}?year=$year&month=$month');
            },
          ),
        );
      },
    );
  }

  BudgetSummaryItem? _findSummaryItem(
      List<BudgetSummaryItem> items, Budget budget) {
    for (final item in items) {
      if (budget.category == null && item.category == null) return item;
      if (budget.category?.id == item.category?.id) return item;
    }
    return null;
  }

  Widget _buildEmpty(BuildContext context) {
    final state = context.read<BudgetBloc>().state;
    final year = state is BudgetLoaded ? state.year : DateTime.now().year;
    final month = state is BudgetLoaded ? state.month : DateTime.now().month;
    return EmptyStateWidget(
      icon: Icons.account_balance_wallet,
      title: '예산이 없습니다',
      subtitle: '이 달에 설정된 예산이 없습니다',
      actionLabel: '예산 추가',
      onAction: () => context.push('/budgets/create?year=$year&month=$month'),
    );
  }

  Widget _buildError(BuildContext context) {
    final now = DateTime.now();
    return AppErrorWidget(
      message: '예산을 불러오지 못했습니다',
      onRetry: () {
        context.read<BudgetBloc>().add(
              LoadBudgets(year: now.year, month: now.month),
            );
      },
      showHomeButton: true,
    );
  }

  Color _getProgressColor(double usageRate) {
    if (usageRate > 100) return Colors.red;
    if (usageRate >= 80) return Colors.orange;
    return Colors.green;
  }

  Color _getCategoryColor(String? colorHex) {
    return parseHexColor(colorHex);
  }

  IconData _getCategoryIcon(String? iconName) {
    return resolveIcon(iconName);
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
              context.read<BudgetBloc>().add(
                    LoadBudgets(year: prev.year, month: prev.month),
                  );
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
                context.read<BudgetBloc>().add(
                      LoadBudgets(year: picked.year, month: picked.month),
                    );
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
              context.read<BudgetBloc>().add(
                    LoadBudgets(year: next.year, month: next.month),
                  );
            },
            tooltip: '다음 달',
          ),
        ],
      ),
    );
  }
}
