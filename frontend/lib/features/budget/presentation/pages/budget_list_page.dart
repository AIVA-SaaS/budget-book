import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/dialog_helpers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/budget/presentation/widgets/budget_summary_card.dart';
import 'package:budget_book/core/widgets/icon_picker.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/core/widgets/color_picker.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/account_balance_card.dart';
import 'package:budget_book/features/budget/presentation/widgets/budget_transactions_sheet.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
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
                  onPressed: () => context.push('/asset-management'),
                  icon: const Icon(Icons.category),
                  tooltip: '자산 관리',
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
                ButtonSegment(value: false, label: Text('월간', maxLines: 1, softWrap: false)),
                ButtonSegment(value: true, label: Text('주간', maxLines: 1, softWrap: false)),
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
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                        );
                      } else if (state is BudgetLoaded &&
                          state.operationError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.operationError!),
                            backgroundColor: Theme.of(context).colorScheme.error,
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
          if (state is WeeklyBudgetInitial) {
            // Ensure events are dispatched
            final now = DateTime.now();
            getIt<WeeklyBudgetBloc>()
              ..add(LoadWeeklyOverview(year: now.year, month: now.month))
              ..add(const LoadCurrentWeek());
          }
          return switch (state) {
            WeeklyBudgetInitial() || WeeklyBudgetLoading() =>
              const Center(child: CircularProgressIndicator()),
            WeeklyBudgetLoaded() when state.overview == null && state.currentWeek == null =>
              _buildWeeklyEmpty(context),
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

  Widget _buildWeeklyEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '주간 예산이 설정되지 않았습니다',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '월간 예산 추가 시 "주간" 기간을 선택하면\n주간 예산이 자동으로 생성됩니다',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyLoaded(BuildContext context, WeeklyBudgetLoaded state) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');

    return Column(
      children: [
        MonthNavigator(
          year: state.year,
          month: state.month,
          onMonthChanged: (m) {
            getIt<WeeklyBudgetBloc>()
                .add(LoadWeeklyOverview(year: m.year, month: m.month));
          },
        ),
        Expanded(
          child: RefreshIndicator(
      onRefresh: () async {
        getIt<WeeklyBudgetBloc>()
          ..add(LoadWeeklyOverview(year: state.year, month: state.month))
          ..add(const LoadCurrentWeek());
      },
      child: ListView(
        key: const PageStorageKey('budget_weekly_list'),
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
                    weekSummary: week,
                    isCurrentWeek: isCurrent,
                    onItemTap: (item) {
                      final parts = state.overview!.yearMonth.split('-');
                      final year = int.parse(parts[0]);
                      final month = int.parse(parts[1]);
                      showBudgetTransactionsSheet(
                        context: context,
                        year: year,
                        month: month,
                        categoryId: item.categoryId,
                        categoryName: item.displayName,
                        dateFrom: week.weekStart,
                        dateTo: week.weekEnd,
                      );
                    }),
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
          const SizedBox(height: 88),
        ],
      ),
          ),
        ),
      ],
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
            if (currentWeek.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTotalChip(context, '총 예산',
                      '${numberFormat.format(currentWeek.totalBudget)}원'),
                  _buildTotalChip(context, '지출',
                      '${numberFormat.format(currentWeek.totalSpent)}원'),
                  _buildTotalChip(context, '잔여',
                      '${numberFormat.format(currentWeek.totalRemaining)}원',
                      color: currentWeek.totalRemaining >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...currentWeek.items.map((item) {
                final progress = (item.usageRate / 100).clamp(0.0, 1.0);
                final statusColor = item.usageRate > 100
                    ? Colors.red
                    : item.usageRate > 80
                        ? Colors.orange
                        : Colors.green;
                return InkWell(
                  onTap: item.categoryId != null
                      ? () {
                          // Parse yearMonth for the API call
                          final parts = currentWeek.yearMonth.split('-');
                          final year = int.parse(parts[0]);
                          final month = int.parse(parts[1]);
                          showBudgetTransactionsSheet(
                            context: context,
                            year: year,
                            month: month,
                            categoryId: item.categoryId,
                            categoryName: item.displayName,
                            dateFrom: currentWeek.weekStart,
                            dateTo: currentWeek.weekEnd,
                          );
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.displayName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                if (item.categoryId != null) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: theme.colorScheme.onPrimaryContainer
                                        .withValues(alpha: 0.5),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${numberFormat.format(item.spentAmount)}원 / ${numberFormat.format(item.budgetAmount)}원',
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
        MonthNavigator(
          year: state.year,
          month: state.month,
          onMonthChanged: (m) => context.read<BudgetBloc>().add(
                LoadBudgets(year: m.year, month: m.month),
              ),
        ),
        if (state.summary != null)
          BudgetSummaryCard(summary: state.summary!),
        Expanded(
          child: state.budgets.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 48),
                    Center(
                      child: Text(
                        '이 달에 설정된 예산이 없습니다',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                      ),
                    ),
                    BlocProvider<PaymentMethodBloc>.value(
                      value: getIt<PaymentMethodBloc>(),
                      child: BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
                        builder: (context, pmState) {
                          if (pmState is PaymentMethodInitial) {
                            getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
                          }
                          if (pmState is! PaymentMethodLoaded) {
                            return const Padding(padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()));
                          }
                          return const AccountBalanceCard(showHeader: false);
                        },
                      ),
                    ),
                    const SizedBox(height: 88),
                  ],
                )
              : _buildBudgetList(context, state),
        ),
      ],
    );
  }

  Widget _buildBudgetList(BuildContext context, BudgetLoaded state) {
    final numberFormat = NumberFormat('#,###');
    final summaryItems = state.summary?.items ?? [];
    final sharedBudgets = state.budgets.where((b) => b.isShared).toList();
    final privateBudgets = state.budgets.where((b) => b.isPrivate).toList();

    final allItems = <Widget>[];

    // Shared budgets
    for (final budget in sharedBudgets) {
      allItems.add(_buildBudgetTile(context, budget, summaryItems, numberFormat));
    }

    // Private budgets section
    if (privateBudgets.isNotEmpty) {
      allItems.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.visibility_off, size: 16),
              const SizedBox(width: 6),
              Text(
                '나만 보임',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      );
      for (final budget in privateBudgets) {
        allItems.add(_buildBudgetTile(context, budget, summaryItems, numberFormat));
      }
    }

    // Payment method asset summary at bottom
    allItems.add(
      BlocProvider<PaymentMethodBloc>.value(
        value: getIt<PaymentMethodBloc>(),
        child: BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
          builder: (context, pmState) {
            if (pmState is PaymentMethodInitial) {
              getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
            }
            if (pmState is! PaymentMethodLoaded) {
              return const Padding(padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()));
            }
            return const AccountBalanceCard(showHeader: false);
          },
        ),
      ),
    );

    allItems.add(const SizedBox(height: 88));
    return ListView(key: const PageStorageKey('budget_monthly_list'), children: allItems);
  }

  Widget _buildBudgetTile(
    BuildContext context,
    Budget budget,
    List<BudgetSummaryItem> summaryItems,
    NumberFormat numberFormat,
  ) {
    final summaryItem = _findSummaryItem(summaryItems, budget);
    final usageRate = summaryItem?.usageRate ?? 0.0;
    // Use BE-calculated budget amount (consistent with totalBudget)
    final displayBudgetAmount = summaryItem?.budgetAmount ?? budget.effectiveMonthlyAmount;

    return Dismissible(
      key: Key(budget.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDeleteConfirmDialog(
          context,
          title: '예산 삭제',
          itemName: budget.targetLabel,
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
        title: Row(
          children: [
            if (budget.isPrivate) ...[
              Icon(
                Icons.visibility_off,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(child: Text(budget.targetLabel)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildBudgetProgressBar(context, summaryItem, displayBudgetAmount),
            const SizedBox(height: 4),
            _buildBudgetSubtitleText(context, summaryItem, displayBudgetAmount, numberFormat, usageRate),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${numberFormat.format(displayBudgetAmount)}원',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                final state = context.read<BudgetBloc>().state;
                final year =
                    state is BudgetLoaded ? state.year : DateTime.now().year;
                final month =
                    state is BudgetLoaded ? state.month : DateTime.now().month;
                if (value == 'transactions') {
                  if (budget.category != null) {
                    showBudgetTransactionsSheet(
                      context: context,
                      year: year,
                      month: month,
                      categoryId: budget.category!.id,
                      categoryName: budget.targetLabel,
                    );
                  }
                } else if (value == 'edit') {
                  context.push(
                      '/budgets/edit/${budget.id}?year=$year&month=$month');
                } else if (value == 'delete') {
                  final confirmed = await showDeleteConfirmDialog(
                    context,
                    title: '예산 삭제',
                    itemName: budget.targetLabel,
                  );
                  if (confirmed && context.mounted) {
                    context
                        .read<BudgetBloc>()
                        .add(DeleteBudget(budget.id));
                  }
                }
              },
              itemBuilder: (context) => [
                if (budget.category != null)
                  const PopupMenuItem(
                    value: 'transactions',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, size: 18),
                        SizedBox(width: 8),
                        Text('거래 보기'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('수정'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('삭제', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          final state = context.read<BudgetBloc>().state;
          final year =
              state is BudgetLoaded ? state.year : DateTime.now().year;
          final month =
              state is BudgetLoaded ? state.month : DateTime.now().month;
          // Show transactions for this budget's category
          if (budget.category != null) {
            showBudgetTransactionsSheet(
              context: context,
              year: year,
              month: month,
              categoryId: budget.category!.id,
              categoryName: budget.targetLabel,
            );
          } else {
            // For group/total budgets, go to edit
            context.push('/budgets/edit/${budget.id}?year=$year&month=$month');
          }
        },
      ),
    );
  }

  /// 3-segment progress bar: spent (solid) + planned (semi-transparent) + remaining (grey).
  Widget _buildBudgetProgressBar(
    BuildContext context,
    BudgetSummaryItem? summaryItem,
    int budgetAmount,
  ) {
    if (budgetAmount <= 0) {
      return const SizedBox.shrink();
    }

    final spentAmount = summaryItem?.spentAmount ?? 0;
    final plannedAmount = summaryItem?.plannedAmount ?? 0;

    final spentRatio = (spentAmount / budgetAmount).clamp(0.0, 1.0);
    final plannedRatio = (plannedAmount / budgetAmount).clamp(0.0, 1.0 - spentRatio);
    final usageRate = summaryItem?.usageRate ?? 0.0;
    final spentColor = _getProgressColor(usageRate);

    // If no planned amount, use simple progress bar
    if (plannedAmount <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: spentRatio,
          minHeight: 6,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          color: spentColor,
        ),
      );
    }

    // 3-segment bar using CustomPaint-like approach with stacked bars
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final spentWidth = totalWidth * spentRatio;
            final plannedWidth = totalWidth * plannedRatio;

            return Stack(
              children: [
                // Background (remaining)
                Container(
                  width: totalWidth,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Planned (semi-transparent, behind spent)
                if (plannedWidth > 0)
                  Positioned(
                    left: spentWidth,
                    child: Container(
                      width: plannedWidth,
                      height: 6,
                      color: spentColor.withValues(alpha: 0.3),
                    ),
                  ),
                // Spent (solid)
                if (spentWidth > 0)
                  Container(
                    width: spentWidth,
                    height: 6,
                    decoration: BoxDecoration(
                      color: spentColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(4),
                        bottomLeft: const Radius.circular(4),
                        topRight: plannedWidth > 0 ? Radius.zero : const Radius.circular(4),
                        bottomRight: plannedWidth > 0 ? Radius.zero : const Radius.circular(4),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Subtitle text showing spent + planned / budget.
  Widget _buildBudgetSubtitleText(
    BuildContext context,
    BudgetSummaryItem? summaryItem,
    int budgetAmount,
    NumberFormat numberFormat,
    double usageRate,
  ) {
    final spentAmount = summaryItem?.spentAmount ?? 0;
    final plannedAmount = summaryItem?.plannedAmount ?? 0;

    if (plannedAmount > 0) {
      return Text(
        '사용 ${numberFormat.format(spentAmount)} + 계획 ${numberFormat.format(plannedAmount)}원 / ${numberFormat.format(budgetAmount)}원 (${usageRate.toStringAsFixed(1)}%)',
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      '${numberFormat.format(spentAmount)}원 / ${numberFormat.format(budgetAmount)}원 (${usageRate.toStringAsFixed(1)}%)',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  BudgetSummaryItem? _findSummaryItem(
      List<BudgetSummaryItem> items, Budget budget) {
    for (final item in items) {
      // Match by category ID
      if (budget.category != null && item.category != null &&
          budget.category!.id == item.category!.id) {
        return item;
      }
      // Match by group ID (group budgets have no category)
      if (budget.category == null && item.category == null &&
          budget.groupId != null && item.groupId != null &&
          budget.groupId == item.groupId) {
        return item;
      }
      // Match total budget (no category, no group)
      if (budget.category == null && item.category == null &&
          budget.groupId == null && item.groupId == null) {
        return item;
      }
    }
    return null;
  }

  // _buildEmpty removed: inline empty state used in _buildLoaded

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

  Widget _buildTotalChip(BuildContext context, String label, String value,
      {Color? color}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color:
                theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color ?? theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }
}

