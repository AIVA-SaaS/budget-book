import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_bloc.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_event.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_state.dart';
import 'package:budget_book/features/recurring/presentation/widgets/recurring_list_tile.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';

class RecurringListPage extends StatelessWidget {
  const RecurringListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('반복 거래'),
      ),
      body: BlocConsumer<RecurringBloc, RecurringState>(
        listener: (context, state) {
          if (state is RecurringError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is RecurringLoaded &&
              state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            RecurringInitial() ||
            RecurringLoading() =>
              const Center(child: CircularProgressIndicator()),
            RecurringLoaded() =>
              _buildContent(context, state),
            RecurringError() => _buildError(context),
          };
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recurring/create'),
        tooltip: '반복 거래 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(BuildContext context, RecurringLoaded state) {
    final theme = Theme.of(context);

    if (state.transactions.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.repeat,
        title: '반복 거래가 없습니다',
        subtitle: '등록된 반복 거래가 없습니다',
        actionLabel: '반복 거래 추가',
        onAction: () => context.push('/recurring/create'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context
            .read<RecurringBloc>()
            .add(const LoadRecurringTransactions());
      },
      child: ListView(
        key: const PageStorageKey('recurring_list'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (state.activeTransactions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '활성 (${state.activeTransactions.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            ...state.activeTransactions.map(
              (t) => RecurringListTile(
                transaction: t,
                onActiveChanged: (value) {
                  context.read<RecurringBloc>().add(
                        UpdateRecurringTransaction(
                          id: t.id,
                          isActive: value,
                        ),
                      );
                },
                onTap: () => context.push('/recurring/edit/${t.id}'),
                onDelete: () {
                  context
                      .read<RecurringBloc>()
                      .add(DeleteRecurringTransaction(t.id));
                },
              ),
            ),
          ],
          if (state.inactiveTransactions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '비활성 (${state.inactiveTransactions.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            ...state.inactiveTransactions.map(
              (t) => RecurringListTile(
                transaction: t,
                onActiveChanged: (value) {
                  context.read<RecurringBloc>().add(
                        UpdateRecurringTransaction(
                          id: t.id,
                          isActive: value,
                        ),
                      );
                },
                onTap: () => context.push('/recurring/edit/${t.id}'),
                onDelete: () {
                  context
                      .read<RecurringBloc>()
                      .add(DeleteRecurringTransaction(t.id));
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return AppErrorWidget(
      message: '반복 거래를 불러오지 못했습니다',
      onRetry: () {
        context
            .read<RecurringBloc>()
            .add(const LoadRecurringTransactions());
      },
      showHomeButton: true,
    );
  }
}
