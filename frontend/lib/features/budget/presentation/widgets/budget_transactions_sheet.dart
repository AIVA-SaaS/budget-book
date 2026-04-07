import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_list_tile.dart';

/// Shows a bottom sheet with transactions filtered by categoryId for a budget item.
void showBudgetTransactionsSheet({
  required BuildContext context,
  required int year,
  required int month,
  required String? categoryId,
  required String categoryName,
  String? dateFrom,
  String? dateTo,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          // Create a separate TransactionBloc instance for this sheet
          final bloc = TransactionBloc(
            transactionRepository: getIt<TransactionRepository>(),
          )..add(LoadTransactions(
              year: year,
              month: month,
              categoryId: categoryId,
              dateFrom: dateFrom,
              dateTo: dateTo,
            ));

          return BlocProvider<TransactionBloc>.value(
            value: bloc,
            child: _BudgetTransactionsContent(
              scrollController: scrollController,
              categoryName: categoryName,
              onDispose: () => bloc.close(),
            ),
          );
        },
      );
    },
  );
}

class _BudgetTransactionsContent extends StatefulWidget {
  final ScrollController scrollController;
  final String categoryName;
  final VoidCallback onDispose;

  const _BudgetTransactionsContent({
    required this.scrollController,
    required this.categoryName,
    required this.onDispose,
  });

  @override
  State<_BudgetTransactionsContent> createState() =>
      _BudgetTransactionsContentState();
}

class _BudgetTransactionsContentState
    extends State<_BudgetTransactionsContent> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Handle bar
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.categoryName} 거래 내역',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              BlocBuilder<TransactionBloc, TransactionState>(
                builder: (context, state) {
                  if (state is TransactionLoaded) {
                    return Text(
                      '${state.totalElements}건',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Transaction list
        Expanded(
          child: BlocBuilder<TransactionBloc, TransactionState>(
            builder: (context, state) {
              if (state is TransactionLoading || state is TransactionInitial) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is TransactionError) {
                return Center(
                  child: Text(
                    '거래를 불러오지 못했습니다',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                );
              }
              if (state is TransactionLoaded) {
                final transactions = state.filteredTransactions;
                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '해당 기간에 거래가 없습니다',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group by date
                final grouped = state.filteredGroupedByDate;
                final sortedDates = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                // Calculate total
                final totalAmount = transactions.fold<int>(
                    0, (sum, t) => sum + t.amount);

                return Column(
                  children: [
                    // Total summary
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '합계',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${CurrencyFormatter.format(totalAmount)}원',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Grouped list
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollUpdateNotification) {
                            final maxScroll =
                                notification.metrics.maxScrollExtent;
                            final currentScroll =
                                notification.metrics.pixels;
                            if (currentScroll >= maxScroll * 0.7) {
                              final bloc = context.read<TransactionBloc>();
                              final s = bloc.state;
                              if (s is TransactionLoaded &&
                                  s.hasMore &&
                                  !s.isLoadingMore) {
                                bloc.add(const LoadMoreTransactions());
                              }
                            }
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: widget.scrollController,
                          itemCount: sortedDates.length +
                              (state.isLoadingMore || state.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= sortedDates.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            final date = sortedDates[index];
                            final items = grouped[date]!;

                            String formatted;
                            try {
                              final d = DateTime.parse(date);
                              formatted =
                                  DateFormat('M월 d일 (E)', 'ko').format(d);
                            } catch (_) {
                              formatted = date;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  color: theme
                                      .colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  child: Text(
                                    formatted,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                ...items.map((t) => TransactionListTile(
                                      transaction: t,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        context.push(
                                            '/transactions/detail/${t.id}');
                                      },
                                    )),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}
