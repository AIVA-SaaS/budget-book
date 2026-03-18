import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/utils/web_download_stub.dart'
    if (dart.library.html) 'package:budget_book/core/utils/web_download_web.dart'
    as web_download;
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/presentation/widgets/month_summary_bar.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_list_tile.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';

class TransactionListPage extends StatefulWidget {
  const TransactionListPage({super.key});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // Filter state
  String? _filterPaymentMethodId;
  String? _filterPocketId;
  int? _filterAmountMin;
  int? _filterAmountMax;
  bool _hasActiveFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _reloadWithFilters();
    });
  }

  void _reloadWithFilters() {
    final state = context.read<TransactionBloc>().state;
    final year = state is TransactionLoaded ? state.year : DateTime.now().year;
    final month =
        state is TransactionLoaded ? state.month : DateTime.now().month;

    final keyword =
        _searchController.text.trim().isEmpty ? null : _searchController.text.trim();

    context.read<TransactionBloc>().add(LoadTransactions(
          year: year,
          month: month,
          keyword: keyword,
          paymentMethodId: _filterPaymentMethodId,
          pocketId: _filterPocketId,
          amountMin: _filterAmountMin,
          amountMax: _filterAmountMax,
        ));
  }

  Future<void> _exportCsv(BuildContext context) async {
    final state = context.read<TransactionBloc>().state;
    final year = state is TransactionLoaded ? state.year : DateTime.now().year;
    final month =
        state is TransactionLoaded ? state.month : DateTime.now().month;

    try {
      final response = await getIt<ApiClient>().dio.get(
        ApiEndpoints.transactionsExportCsv,
        queryParameters: {'year': year, 'month': month},
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data as List<int>;
      final filename = 'transactions_${year}_$month.csv';

      if (kIsWeb) {
        web_download.triggerBrowserDownload(bytes, filename, 'text/csv');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV 내보내기 완료')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e')),
        );
      }
    }
  }

  void _showFilterSheet() {
    final amountMinController = TextEditingController(
      text: _filterAmountMin?.toString() ?? '',
    );
    final amountMaxController = TextEditingController(
      text: _filterAmountMax?.toString() ?? '',
    );
    String? tempPaymentMethodId = _filterPaymentMethodId;
    String? tempPocketId = _filterPocketId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '필터',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  // Amount range
                  Text(
                    '금액 범위',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountMinController,
                          decoration: const InputDecoration(
                            labelText: '최소 금액',
                            hintText: '0',
                            suffixText: '원',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('~'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: amountMaxController,
                          decoration: const InputDecoration(
                            labelText: '최대 금액',
                            hintText: '무제한',
                            suffixText: '원',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Payment method ID
                  TextField(
                    decoration: InputDecoration(
                      labelText: '결제수단 ID',
                      hintText: '결제수단 ID를 입력하세요',
                      suffixIcon: tempPaymentMethodId != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setSheetState(
                                    () => tempPaymentMethodId = null);
                              },
                            )
                          : null,
                    ),
                    controller:
                        TextEditingController(text: tempPaymentMethodId ?? ''),
                    onChanged: (value) {
                      tempPaymentMethodId =
                          value.trim().isEmpty ? null : value.trim();
                    },
                  ),
                  const SizedBox(height: 16),
                  // Pocket ID
                  TextField(
                    decoration: InputDecoration(
                      labelText: '포켓 ID',
                      hintText: '포켓 ID를 입력하세요',
                      suffixIcon: tempPocketId != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setSheetState(() => tempPocketId = null);
                              },
                            )
                          : null,
                    ),
                    controller:
                        TextEditingController(text: tempPocketId ?? ''),
                    onChanged: (value) {
                      tempPocketId =
                          value.trim().isEmpty ? null : value.trim();
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _filterPaymentMethodId = null;
                              _filterPocketId = null;
                              _filterAmountMin = null;
                              _filterAmountMax = null;
                              _hasActiveFilters = false;
                            });
                            Navigator.of(ctx).pop();
                            _reloadWithFilters();
                          },
                          child: const Text('초기화'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final minText = amountMinController.text.trim();
                            final maxText = amountMaxController.text.trim();
                            setState(() {
                              _filterAmountMin =
                                  minText.isEmpty ? null : int.tryParse(minText);
                              _filterAmountMax =
                                  maxText.isEmpty ? null : int.tryParse(maxText);
                              _filterPaymentMethodId = tempPaymentMethodId;
                              _filterPocketId = tempPocketId;
                              _hasActiveFilters = _filterAmountMin != null ||
                                  _filterAmountMax != null ||
                                  _filterPaymentMethodId != null ||
                                  _filterPocketId != null;
                            });
                            Navigator.of(ctx).pop();
                            _reloadWithFilters();
                          },
                          child: const Text('적용'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: '가져오기',
            onPressed: () => context.push('/transactions/import'),
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: '내보내기',
            onPressed: () => _exportCsv(context),
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
          } else if (state is TransactionLoaded &&
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
            TransactionInitial() || TransactionLoading() =>
              const SkeletonLoader(itemCount: 5),
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
        MonthNavigator(
          year: state.year,
          month: state.month,
          onMonthChanged: (m) {
            final kw = _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim();
            context.read<TransactionBloc>().add(
                  LoadTransactions(
                    year: m.year,
                    month: m.month,
                    keyword: kw,
                    paymentMethodId: _filterPaymentMethodId,
                    pocketId: _filterPocketId,
                    amountMin: _filterAmountMin,
                    amountMax: _filterAmountMax,
                  ),
                );
          },
        ),
        // Search bar and filter button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '거래 검색...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _reloadWithFilters();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: _hasActiveFilters,
                child: IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: _showFilterSheet,
                  tooltip: '필터',
                ),
              ),
            ],
          ),
        ),
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

    // Add 1 extra item for the loading indicator when loading more
    final itemCount =
        sortedDates.length + (state.isLoadingMore || state.hasMore ? 1 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final maxScroll = notification.metrics.maxScrollExtent;
          final currentScroll = notification.metrics.pixels;
          // Trigger load more at 80% scroll
          if (currentScroll >= maxScroll * 0.8) {
            final bloc = context.read<TransactionBloc>();
            final currentState = bloc.state;
            if (currentState is TransactionLoaded &&
                currentState.hasMore &&
                !currentState.isLoadingMore) {
              bloc.add(const LoadMoreTransactions());
            }
          }
        }
        return false;
      },
      child: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Last item is loading indicator
          if (index >= sortedDates.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final date = sortedDates[index];
          final transactions = grouped[date]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateHeader(dateStr: date),
              ...transactions.map((t) => TransactionListTile(
                    transaction: t,
                    onTap: () => context.push('/transactions/detail/${t.id}'),
                    onDelete: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('거래 삭제'),
                          content: const Text('정말 삭제하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('취소'),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                context
                                    .read<TransactionBloc>()
                                    .add(DeleteTransaction(t.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('거래가 삭제되었습니다'),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              child: const Text('삭제'),
                            ),
                          ],
                        ),
                      );
                    },
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.receipt_long,
      title: '거래 내역이 없습니다',
      subtitle: '이 달에 기록된 거래가 없습니다',
      actionLabel: '거래 추가',
      onAction: () => context.push('/transactions/create'),
    );
  }

  Widget _buildError(BuildContext context) {
    final now = DateTime.now();
    return AppErrorWidget(
      message: '거래를 불러오지 못했습니다',
      onRetry: () {
        context.read<TransactionBloc>().add(
              LoadTransactions(year: now.year, month: now.month),
            );
      },
      showHomeButton: true,
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
