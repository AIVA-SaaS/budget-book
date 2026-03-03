import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/presentation/widgets/month_summary_bar.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_list_tile.dart';

class TransactionListPage extends StatelessWidget {
  const TransactionListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Book'),
        actions: [
          IconButton(
            onPressed: () => context.push('/categories'),
            icon: const Icon(Icons.category),
            tooltip: '카테고리 관리',
          ),
          IconButton(
            onPressed: () => context.push('/couple'),
            icon: const Icon(Icons.favorite),
            tooltip: '커플 연결',
          ),
        ],
      ),
      body: BlocConsumer<TransactionBloc, TransactionState>(
        listener: (context, state) {
          if (state is TransactionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is TransactionLoaded &&
              state.operationError != null) {
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
            TransactionInitial() || TransactionLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            TransactionLoaded() => _buildLoaded(context, state),
            TransactionError() => _buildError(context),
          };
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transactions/create'),
        tooltip: '거래 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, TransactionLoaded state) {
    return Column(
      children: [
        // Month navigator
        _MonthNavigator(year: state.year, month: state.month),
        // Summary bar
        MonthSummaryBar(
          totalIncome: state.totalIncome,
          totalExpense: state.totalExpense,
          balance: state.balance,
        ),
        // Transaction list grouped by date
        Expanded(
          child: state.transactions.isEmpty
              ? _buildEmpty(context)
              : _buildGroupedList(context, state),
        ),
      ],
    );
  }

  Widget _buildGroupedList(BuildContext context, TransactionLoaded state) {
    final grouped = state.groupedByDate;
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final transactions = grouped[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(dateStr: date),
            ...transactions.map((t) => TransactionListTile(
                  transaction: t,
                  onTap: () => context.push('/transactions/edit/${t.id}', extra: t),
                  onDelete: () {
                    context
                        .read<TransactionBloc>()
                        .add(DeleteTransaction(t.id));
                  },
                )),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '이 달에 기록된 거래가 없습니다',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '+ 버튼을 눌러 첫 거래를 추가하세요',
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
          const Text('거래를 불러오지 못했습니다'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              context.read<TransactionBloc>().add(
                    LoadTransactions(year: now.year, month: now.month),
                  );
            },
            child: const Text('다시 시도'),
          ),
        ],
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
              context.read<TransactionBloc>().add(
                    LoadTransactions(year: prev.year, month: prev.month),
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
                context.read<TransactionBloc>().add(
                      LoadTransactions(
                          year: picked.year, month: picked.month),
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
              context.read<TransactionBloc>().add(
                    LoadTransactions(year: next.year, month: next.month),
                  );
            },
            tooltip: '다음 달',
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String dateStr;

  const _DateHeader({required this.dateStr});

  @override
  Widget build(BuildContext context) {
    String formatted;
    try {
      final date = DateTime.parse(dateStr);
      formatted = DateFormat('M월 d일 (E)', 'ko').format(date);
    } catch (_) {
      formatted = dateStr;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.5),
      child: Text(
        formatted,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
      ),
    );
  }
}
