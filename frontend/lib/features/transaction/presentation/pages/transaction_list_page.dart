import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/utils/web_download_stub.dart'
    if (dart.library.html) 'package:budget_book/core/utils/web_download_web.dart'
    as web_download;
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/ledger_item.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/presentation/widgets/month_summary_bar.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_list_tile.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transfer_list_tile.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_state.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/core/widgets/filters/unified_filter_bar.dart';
import 'package:budget_book/core/widgets/filters/payment_method_filter.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/card_pending_summary.dart';

class TransactionListPage extends StatefulWidget {
  final String? initialPaymentMethodId;
  final String? initialPaymentMethodName;
  final String? initialCategoryId;
  final String? initialCategoryName;

  const TransactionListPage({
    super.key,
    this.initialPaymentMethodId,
    this.initialPaymentMethodName,
    this.initialCategoryId,
    this.initialCategoryName,
  });

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dateKeys = {};
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isSearching = false;
  String? _pendingScrollToDate;

  // Unified filter state
  late UnifiedFilterState _filterState = UnifiedFilterState(
    categoryIds: widget.initialCategoryId != null ? {widget.initialCategoryId!} : const {},
    categoryName: widget.initialCategoryName,
    paymentMethodIds: widget.initialPaymentMethodId != null ? {widget.initialPaymentMethodId!} : const {},
    paymentMethodName: widget.initialPaymentMethodName,
  );

  String get _appBarTitle {
    if (!_filterState.hasActiveFilters) return '거래 (전체)';
    if (_filterState.categoryName != null) return '거래 (${_filterState.categoryName})';
    if (_filterState.paymentMethodName != null) return '거래 (${_filterState.paymentMethodName})';
    return '거래 (필터)';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPaymentMethodId != null && _filterState.paymentMethodName == null) {
      final name = PaymentMethodFilter.resolveName(widget.initialPaymentMethodId!);
      if (name != null) {
        setState(() {
          _filterState = _filterState.copyWith(paymentMethodName: name);
        });
      }
    }
    // Load card pending for the current month
    final now = DateTime.now();
    getIt<PaymentMethodBloc>().add(LoadCardPending(year: now.year, month: now.month));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _isSearching = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _reloadWithFilters();
      // Restore focus after reload completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isSearching && mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    });
  }

  void _reloadWithFilters() {
    final state = context.read<TransactionBloc>().state;
    final year = state is TransactionLoaded ? state.year : DateTime.now().year;
    final month =
        state is TransactionLoaded ? state.month : DateTime.now().month;

    final keyword =
        _searchController.text.trim().isEmpty ? null : _searchController.text.trim();

    final fmt = DateFormat('yyyy-MM-dd');
    context.read<TransactionBloc>().add(LoadTransactions(
          year: year,
          month: month,
          keyword: keyword,
          type: _filterState.transactionType,
          categoryId: _filterState.categoryIds.isNotEmpty ? _filterState.categoryIds.first : null,
          paymentMethodId: _filterState.paymentMethodIds.isNotEmpty ? _filterState.paymentMethodIds.first : null,
          pocketId: _filterState.pocketIds.isNotEmpty ? _filterState.pocketIds.first : null,
          amountMin: _filterState.amountMin,
          amountMax: _filterState.amountMax,
          dateFrom: _filterState.dateFrom != null ? fmt.format(_filterState.dateFrom!) : null,
          dateTo: _filterState.dateTo != null ? fmt.format(_filterState.dateTo!) : null,
        ));
    context.read<TransferBloc>().add(LoadTransfers(year: year, month: month));
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

  void _onFilterChanged(UnifiedFilterState newState) {
    // Resolve payment method name if ID changed
    if (newState.paymentMethodIds.isNotEmpty &&
        newState.paymentMethodName == null) {
      final name = PaymentMethodFilter.resolveName(
          newState.paymentMethodIds.first);
      if (name != null) {
        newState = newState.copyWith(paymentMethodName: name);
      }
    }
    setState(() => _filterState = newState);
    _reloadWithFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final bloc = context.watch<TransactionBloc>();
            final state = bloc.state;
            final count = state is TransactionLoaded ? state.totalElements : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_appBarTitle, style: const TextStyle(fontSize: 18)),
                if (count != null)
                  Text(
                    '$count건',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            );
          },
        ),
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
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is TransactionLoaded &&
              state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Theme.of(context).colorScheme.error,
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
        onPressed: () {
          final pmId = _filterState.paymentMethodIds.isNotEmpty
              ? _filterState.paymentMethodIds.first
              : null;
          final pmParam = pmId != null
              ? '&paymentMethodId=$pmId'
              : '';
          context.push('/transactions/create?tab=expense$pmParam');
        },
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
          onDatePicked: (picked) {
            // Store the target date for scroll-after-load
            final day = picked.day;
            if (day > 1) {
              final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              setState(() => _pendingScrollToDate = dateStr);
            }
          },
          onMonthChanged: (m) {
            // Clear period filter when navigating months
            setState(() {
              _filterState = _filterState.copyWith(clearDateRange: true);
            });
            final kw = _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim();
            final fmt = DateFormat('yyyy-MM-dd');
            context.read<TransactionBloc>().add(
                  LoadTransactions(
                    year: m.year,
                    month: m.month,
                    keyword: kw,
                    categoryId: _filterState.categoryIds.isNotEmpty ? _filterState.categoryIds.first : null,
                    paymentMethodId: _filterState.paymentMethodIds.isNotEmpty ? _filterState.paymentMethodIds.first : null,
                    pocketId: _filterState.pocketIds.isNotEmpty ? _filterState.pocketIds.first : null,
                    amountMin: _filterState.amountMin,
                    amountMax: _filterState.amountMax,
                    dateFrom: _filterState.dateFrom != null ? fmt.format(_filterState.dateFrom!) : null,
                    dateTo: _filterState.dateTo != null ? fmt.format(_filterState.dateTo!) : null,
                    scrollToDate: _pendingScrollToDate,
                  ),
                );
            context.read<TransferBloc>().add(
                  LoadTransfers(year: m.year, month: m.month),
                );
            getIt<PaymentMethodBloc>().add(
                  LoadCardPending(year: m.year, month: m.month),
                );
          },
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: '거래 검색...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _isSearching = false;
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
        // Unified filter bar (category, payment, pocket, amount, date range)
        UnifiedFilterBar(
          enabledFilters: const {
            FilterType.transactionType,
            FilterType.visibility,
            FilterType.dateRange,
            FilterType.category,
            FilterType.paymentMethod,
            FilterType.pocket,
            FilterType.amountRange,
          },
          state: _filterState,
          onFilterChanged: _onFilterChanged,
        ),
        // Summary bar + Transaction list (both need transfers)
        Expanded(
          child: BlocBuilder<TransferBloc, TransferState>(
            builder: (context, transferState) {
              final transfers = transferState is TransferLoaded
                  ? transferState.transfers
                  : <Transfer>[];

              // Filter transfers by payment method if filter is active
              final filterPmId = _filterState.paymentMethodIds.isNotEmpty
                  ? _filterState.paymentMethodIds.first
                  : null;
              final filteredTransfers = filterPmId != null
                  ? transfers.where((t) =>
                      t.sourcePaymentMethod.id == filterPmId ||
                      t.destinationPaymentMethod.id == filterPmId).toList()
                  : transfers;

              // Filter transfers by date if date filter is active
              final fmt = DateFormat('yyyy-MM-dd');
              final filterDateFrom = _filterState.dateFrom != null ? fmt.format(_filterState.dateFrom!) : null;
              final filterDateTo = _filterState.dateTo != null ? fmt.format(_filterState.dateTo!) : null;
              final dateFilteredTransfers = filterDateFrom != null || filterDateTo != null
                  ? filteredTransfers.where((t) {
                      if (filterDateFrom != null && t.transferDate.compareTo(filterDateFrom) < 0) return false;
                      if (filterDateTo != null && t.transferDate.compareTo(filterDateTo) > 0) return false;
                      return true;
                    }).toList()
                  : filteredTransfers;

              // Filter transfers by keyword if search is active
              final keyword = _searchController.text.trim().toLowerCase();
              final searchedTransfers = keyword.isEmpty
                  ? dateFilteredTransfers
                  : dateFilteredTransfers.where((t) {
                      final desc = t.description?.toLowerCase() ?? '';
                      final src = t.sourcePaymentMethod.name.toLowerCase();
                      final dst = t.destinationPaymentMethod.name.toLowerCase();
                      return desc.contains(keyword) ||
                          src.contains(keyword) ||
                          dst.contains(keyword);
                    }).toList();

              // Calculate transfer in/out relative to current payment method filter
              int transferIn = 0;
              int transferOut = 0;
              for (final t in searchedTransfers) {
                if (filterPmId != null) {
                  // Per-payment-method view: in/out relative to this method
                  if (t.sourcePaymentMethod.id == filterPmId) {
                    transferOut += t.amount;
                  }
                  if (t.destinationPaymentMethod.id == filterPmId) {
                    transferIn += t.amount;
                  }
                } else {
                  // Global view: transfers are internal moves
                  transferOut += t.amount;
                }
              }

              // When serverTotalIncome/Expense are available (from /statistics/summary),
              // they already include transfer amounts. Don't add transfers again.
              // Only add transfers when using client-calculated totals (filters active).
              final hasServerTotals = state.serverTotalIncome != null;
              final displayIncome = hasServerTotals
                  ? state.totalIncome
                  : state.totalIncome + transferIn;
              final displayExpense = hasServerTotals
                  ? state.totalExpense
                  : state.totalExpense + transferOut;

              return Column(
                children: [
                  MonthSummaryBar(
                    totalIncome: displayIncome,
                    totalExpense: displayExpense,
                    balance: displayIncome - displayExpense,
                    totalTransfer: transferIn + transferOut > 0 ? transferIn + transferOut : null,
                  ),
                  // Card pending summary (credit card settlement)
                  BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
                    bloc: getIt<PaymentMethodBloc>(),
                    buildWhen: (prev, curr) =>
                        prev is! PaymentMethodLoaded ||
                        curr is! PaymentMethodLoaded ||
                        prev.cardPendings != curr.cardPendings,
                    builder: (context, pmState) {
                      if (pmState is PaymentMethodLoaded &&
                          pmState.cardPendings != null &&
                          pmState.cardPendings!.any((cp) => cp.pendingAmount > 0)) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: CardPendingSummary(cardPendings: pmState.cardPendings!),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  if (state.filteredTransactions.isEmpty && searchedTransfers.isEmpty)
                    Expanded(child: _buildEmpty(context))
                  else
                    Expanded(child: _buildGroupedList(context, state, searchedTransfers)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedList(BuildContext context, TransactionLoaded state, List<Transfer> transfers) {
    // Merge transactions and transfers into LedgerItems, grouped by date
    // Use filteredGroupedByDate when date filter is active
    final groupedItems = <String, List<LedgerItem>>{};

    // Add transactions (filtered by date if applicable)
    final txnGrouped = state.filteredGroupedByDate;
    for (final entry in txnGrouped.entries) {
      groupedItems.putIfAbsent(entry.key, () => []);
      for (final t in entry.value) {
        groupedItems[entry.key]!.add(LedgerItem.fromTransaction(t));
      }
    }

    // Add transfers
    for (final transfer in transfers) {
      groupedItems.putIfAbsent(transfer.transferDate, () => []);
      groupedItems[transfer.transferDate]!.add(LedgerItem.fromTransfer(transfer));
    }

    final sortedDates = groupedItems.keys.toList()..sort((a, b) => b.compareTo(a));

    // Handle scroll-to-date (one-shot: consume and clear immediately)
    final targetDate = _pendingScrollToDate;
    if (targetDate != null) {
      _pendingScrollToDate = null; // always consume to prevent infinite loops
      if (sortedDates.contains(targetDate)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToDate(targetDate, sortedDates);
        });
      }
      // If target date not loaded, user can scroll manually — no auto-load
    } else if (state.scrollToDate != null && sortedDates.contains(state.scrollToDate!)) {
      // One-shot scroll from BLoC (e.g., after create/update)
      final scrollDate = state.scrollToDate!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToDate(scrollDate, sortedDates);
      });
    }

    // Calculate running totals for transactions only (transfers are not income/expense)
    final flatTransactions = <Transaction>[];
    for (final date in sortedDates) {
      for (final item in groupedItems[date]!) {
        if (item.isTransaction) {
          flatTransactions.add(item.transaction!);
        }
      }
    }
    final runningTotals = <String, int>{};
    int cumulative = 0;
    for (int i = flatTransactions.length - 1; i >= 0; i--) {
      final t = flatTransactions[i];
      cumulative += t.isExpense ? -t.amount : t.amount;
      runningTotals[t.id] = cumulative;
    }
    // Offset running totals to account for unloaded older transactions
    if (state.serverTotalIncome != null && state.serverTotalExpense != null) {
      final serverBalance = state.serverTotalIncome! - state.serverTotalExpense!;
      final offset = serverBalance - cumulative;
      if (offset != 0) {
        for (final key in runningTotals.keys.toList()) {
          runningTotals[key] = runningTotals[key]! + offset;
        }
      }
    }

    // Add 1 extra item for the loading indicator when loading more
    final itemCount =
        sortedDates.length + (state.isLoadingMore || state.hasMore ? 1 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final maxScroll = notification.metrics.maxScrollExtent;
          final currentScroll = notification.metrics.pixels;
          // Trigger load more at 70% scroll for smoother infinite scrolling
          if (currentScroll >= maxScroll * 0.7) {
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
        controller: _scrollController,
        key: const PageStorageKey('transaction_list'),
        itemCount: itemCount + 1, // +1 for FAB padding
        itemBuilder: (context, index) {
          // Last item is FAB bottom padding
          if (index == itemCount) return const SizedBox(height: 88);
          // Loading indicator
          if (index >= sortedDates.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final date = sortedDates[index];
          final items = groupedItems[date]!;
          final dateKey = _dateKeys.putIfAbsent(date, () => GlobalKey());

          // Calculate day income/expense from transactions only
          final dayTransactions = items.where((i) => i.isTransaction).map((i) => i.transaction!);
          final dayTransferCount = items.where((i) => i.isTransfer).length;

          return Column(
            key: dateKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateHeader(
                dateStr: date,
                dayIncome: dayTransactions.where((t) => t.isIncome).fold(0, (s, t) => s + t.amount),
                dayExpense: dayTransactions.where((t) => t.isExpense).fold(0, (s, t) => s + t.amount),
                dayTransferCount: dayTransferCount,
              ),
              ...items.map((item) {
                if (item.isTransfer) {
                  return TransferListTile(
                    transfer: item.transfer!,
                    onTap: () => context.push('/transfers/edit/${item.transfer!.id}'),
                  );
                }
                final t = item.transaction!;
                return TransactionListTile(
                  transaction: t,
                  runningTotal: runningTotals[t.id],
                  onTap: () => context.push('/transactions/detail/${t.id}'),
                  onLongPress: () => _showTransactionActions(context, t),
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
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _showTransactionActions(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                transaction.description,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('수정'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/transactions/edit/${transaction.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('날짜 이동'),
              onTap: () {
                Navigator.pop(ctx);
                _showDateMoveDialog(context, transaction);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('복사'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/transactions/create', extra: transaction);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('삭제', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteTransaction(context, transaction);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDateMoveDialog(BuildContext context, Transaction transaction) async {
    final bloc = context.read<TransactionBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final initialDate = DateTime.tryParse(transaction.transactionDate) ?? DateTime.now();
    final pickedDate = await showCalendarPickerDialog(
      context: context,
      initialDate: initialDate,
    );
    if (pickedDate != null && mounted) {
      final newDateStr = DateFormat('yyyy-MM-dd').format(pickedDate);
      if (newDateStr != transaction.transactionDate) {
        bloc.add(
          UpdateTransaction(
            id: transaction.id,
            transactionDate: newDateStr,
          ),
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text('거래가 ${DateFormat('M월 d일').format(pickedDate)}로 이동되었습니다'),
          ),
        );
      }
    }
  }

  void _confirmDeleteTransaction(BuildContext context, Transaction transaction) {
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
              context.read<TransactionBloc>().add(DeleteTransaction(transaction.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('거래가 삭제되었습니다')),
              );
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

  void _scrollToDate(String targetDate, List<String> sortedDates) {
    final key = _dateKeys[targetDate];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
  final int dayIncome;
  final int dayExpense;
  final int dayTransferCount;

  const _DateHeader({
    required this.dateStr,
    this.dayIncome = 0,
    this.dayExpense = 0,
    this.dayTransferCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    String formatted;
    try {
      final date = DateTime.parse(dateStr);
      formatted = DateFormat('M월 d일 (E)', 'ko').format(date);
    } catch (_) {
      formatted = dateStr;
    }

    return InkWell(
      onTap: () => context.push('/transactions/create?date=$dateStr'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        child: Row(
          children: [
            Text(
              formatted,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const Spacer(),
            if (dayIncome > 0)
              Text(
                '+${CurrencyFormatter.format(dayIncome)}',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade600, fontWeight: FontWeight.w500),
              ),
            if (dayIncome > 0 && dayExpense > 0)
              const SizedBox(width: 6),
            if (dayExpense > 0)
              Text(
                '-${CurrencyFormatter.format(dayExpense)}',
                style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.w500),
              ),
            if (dayTransferCount > 0) ...[
              if (dayIncome > 0 || dayExpense > 0)
                const SizedBox(width: 6),
              Icon(Icons.swap_horiz, size: 12, color: Colors.teal.shade600),
              const SizedBox(width: 1),
              Text(
                '$dayTransferCount',
                style: TextStyle(fontSize: 11, color: Colors.teal.shade600, fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(width: 8),
            Icon(
              Icons.add_circle_outline,
              size: 16,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

