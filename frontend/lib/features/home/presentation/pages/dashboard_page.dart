import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/core/widgets/announcement_banner.dart';
import 'package:budget_book/features/budget/presentation/widgets/budget_alert_widget.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transactions/create'),
        tooltip: '거래 추가',
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: const Text('Budget Book'),
        actions: [
          IconButton(
            onPressed: () => context.push('/couple'),
            icon: const Icon(Icons.favorite),
            tooltip: '커플 연결',
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading || state is DashboardInitial) {
            return const SkeletonLoader(itemCount: 5);
          }

          if (state is DashboardError) {
            return AppErrorWidget(
              message: state.message,
              onRetry: () {
                final now = DateTime.now();
                context.read<DashboardBloc>().add(
                      LoadDashboard(year: now.year, month: now.month),
                    );
              },
            );
          }

          if (state is DashboardLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<DashboardBloc>().add(
                      LoadDashboard(year: state.year, month: state.month),
                    );
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Announcement banner
                  const AnnouncementBanner(),
                  // Budget alerts
                  const BudgetAlertWidget(),
                  // Month/Year header with navigation
                  _MonthHeader(year: state.year, month: state.month),
                  const SizedBox(height: 16),
                  // Quick action buttons
                  const _QuickActions(),
                  const SizedBox(height: 16),
                  // Summary card
                  _SummaryCard(state: state),
                  const SizedBox(height: 16),
                  // Budget usage card
                  if (state.budgetSummary != null)
                    _BudgetUsageCard(budgetSummary: state.budgetSummary!),
                  if (state.budgetSummary != null) const SizedBox(height: 16),
                  // Recent transactions
                  _RecentTransactionsCard(
                    transactions: state.recentTransactions,
                    error: state.transactionsError,
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final int year;
  final int month;

  const _MonthHeader({required this.year, required this.month});

  void _goToPreviousMonth(BuildContext context) {
    int newYear = year;
    int newMonth = month - 1;
    if (newMonth < 1) {
      newMonth = 12;
      newYear -= 1;
    }
    context.read<DashboardBloc>().add(
          LoadDashboard(year: newYear, month: newMonth),
        );
  }

  void _goToNextMonth(BuildContext context) {
    int newYear = year;
    int newMonth = month + 1;
    if (newMonth > 12) {
      newMonth = 1;
      newYear += 1;
    }
    context.read<DashboardBloc>().add(
          LoadDashboard(year: newYear, month: newMonth),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _goToPreviousMonth(context),
          tooltip: '이전 달',
        ),
        Text(
          '$year년 $month월',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _goToNextMonth(context),
          tooltip: '다음 달',
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickActionButton(
          icon: Icons.arrow_downward,
          label: '지출',
          color: Colors.red,
          onTap: () => context.push('/transactions/create?type=EXPENSE'),
        ),
        _QuickActionButton(
          icon: Icons.arrow_upward,
          label: '수입',
          color: Colors.blue,
          onTap: () => context.push('/transactions/create?type=INCOME'),
        ),
        _QuickActionButton(
          icon: Icons.bar_chart,
          label: '통계',
          color: Colors.purple,
          onTap: () {
            // Navigate to statistics tab (index 3)
            final shell = StatefulNavigationShell.maybeOf(context);
            if (shell != null) {
              shell.goBranch(3);
            } else {
              context.go('/statistics');
            }
          },
        ),
        _QuickActionButton(
          icon: Icons.settings,
          label: '설정',
          color: Colors.grey,
          onTap: () {
            // Navigate to settings tab (index 4)
            final shell = StatefulNavigationShell.maybeOf(context);
            if (shell != null) {
              shell.goBranch(4);
            } else {
              context.go('/settings');
            }
          },
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DashboardLoaded state;

  const _SummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    final formatter = NumberFormat('#,###');

    if (state.summaryError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('요약 정보를 불러올 수 없습니다: ${state.summaryError}'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이번 달 요약',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: '수입',
                    amount: summary?.totalIncome ?? 0,
                    color: Colors.blue,
                    formatter: formatter,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '지출',
                    amount: summary?.totalExpense ?? 0,
                    color: Colors.red,
                    formatter: formatter,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '잔액',
                    amount: summary?.balance ?? 0,
                    color: (summary?.balance ?? 0) >= 0
                        ? Colors.green
                        : Colors.red,
                    formatter: formatter,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final NumberFormat formatter;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatter.format(amount)}원',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _BudgetUsageCard extends StatelessWidget {
  final BudgetSummary budgetSummary;

  const _BudgetUsageCard({required this.budgetSummary});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final usageRate = budgetSummary.usageRate;
    final isOver = budgetSummary.isOverBudget;
    final progressColor = isOver
        ? Colors.red
        : usageRate > 80
            ? Colors.orange
            : Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '예산 사용 현황',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${usageRate.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: progressColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (usageRate / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                color: progressColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '사용: ${formatter.format(budgetSummary.totalSpent)}원',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '예산: ${formatter.format(budgetSummary.totalBudget)}원',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (isOver)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '예산을 ${formatter.format(budgetSummary.totalSpent - budgetSummary.totalBudget)}원 초과했습니다',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  final List<Transaction> transactions;
  final String? error;

  const _RecentTransactionsCard({
    required this.transactions,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 거래',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    final shell = StatefulNavigationShell.maybeOf(context);
                    if (shell != null) {
                      shell.goBranch(1);
                    } else {
                      context.go('/transactions');
                    }
                  },
                  child: const Text('더보기'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (error != null)
              Text('거래 내역을 불러올 수 없습니다: $error'),
            if (error == null && transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '이번 달 거래 내역이 없습니다',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ),
              ),
            if (error == null)
              ...transactions.map(
                (txn) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        txn.isIncome
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 20,
                        color: txn.isIncome ? Colors.blue : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              txn.description,
                              style:
                                  Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${txn.transactionDate}  ${txn.category?.name ?? '미분류'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${txn.isExpense ? "-" : "+"}${formatter.format(txn.amount)}원',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: txn.isIncome
                                      ? Colors.blue
                                      : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
