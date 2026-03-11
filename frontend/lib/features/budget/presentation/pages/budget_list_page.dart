import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/budget/presentation/widgets/budget_summary_card.dart';

class BudgetListPage extends StatelessWidget {
  const BudgetListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('예산 관리'),
        actions: [
          IconButton(
            onPressed: () => context.push('/categories'),
            icon: const Icon(Icons.category),
            tooltip: '카테고리 관리',
          ),
        ],
      ),
      body: BlocConsumer<BudgetBloc, BudgetState>(
        listener: (context, state) {
          if (state is BudgetError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is BudgetLoaded && state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            BudgetInitial() || BudgetLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            BudgetLoaded() => _buildLoaded(context, state),
            BudgetError() => _buildError(context),
          };
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final state = context.read<BudgetBloc>().state;
          final year =
              state is BudgetLoaded ? state.year : DateTime.now().year;
          final month =
              state is BudgetLoaded ? state.month : DateTime.now().month;
          context.push('/budgets/create', extra: {'year': year, 'month': month});
        },
        tooltip: '예산 추가',
        child: const Icon(Icons.add),
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
              context.push('/budgets/edit/${budget.id}', extra: {
                'budget': budget,
                'year': year,
                'month': month,
              });
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '이 달에 설정된 예산이 없습니다',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '+ 버튼을 눌러 예산을 설정하세요',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final now = DateTime.now();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('예산을 불러오지 못했습니다'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              context.read<BudgetBloc>().add(
                    LoadBudgets(year: now.year, month: now.month),
                  );
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double usageRate) {
    if (usageRate > 100) return Colors.red;
    if (usageRate >= 80) return Colors.orange;
    return Colors.green;
  }

  Color _getCategoryColor(String? colorHex) {
    if (colorHex == null) return Colors.grey;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'home':
        return Icons.home;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'checkroom':
        return Icons.checkroom;
      case 'savings':
        return Icons.savings;
      case 'work':
        return Icons.work;
      default:
        return Icons.account_balance_wallet;
    }
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
