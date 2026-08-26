import 'package:flutter/material.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';
import '../../../../core/theme/bb_scale.dart';

/// Shows a bottom sheet for searching and selecting a transaction to link to a spending plan.
Future<Transaction?> showLinkTransactionSheet({
  required BuildContext context,
  required SpendingPlan plan,
}) {
  return showModalBottomSheet<Transaction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _LinkTransactionSheet(plan: plan),
  );
}

class _LinkTransactionSheet extends StatefulWidget {
  final SpendingPlan plan;

  const _LinkTransactionSheet({required this.plan});

  @override
  State<_LinkTransactionSheet> createState() => _LinkTransactionSheetState();
}

class _LinkTransactionSheetState extends State<_LinkTransactionSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions({String? keyword}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final repo = getIt<TransactionRepository>();

    // Determine month from plan's target date
    int? year;
    int? month;
    if (widget.plan.targetDate != null) {
      final date = DateTime.tryParse(widget.plan.targetDate!);
      if (date != null) {
        year = date.year;
        month = date.month;
      }
    }
    year ??= DateTime.now().year;
    month ??= DateTime.now().month;

    final result = await repo.getTransactions(
      year: year,
      month: month,
      filter: TransactionFilter(
        type: 'EXPENSE',
        categoryId: keyword == null ? widget.plan.categoryId : null,
        keyword: keyword,
      ),
      size: 50,
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _isLoading = false;
      }),
      (page) => setState(() {
        _transactions = page.content;
        _isLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '거래 연결',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${widget.plan.name}에 연결할 거래를 선택하세요',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '거래 설명 검색',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadTransactions();
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (value) {
                  _loadTransactions(keyword: value.isEmpty ? null : value);
                },
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.lg),
            // Transaction list
            Expanded(
              child: _buildContent(scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            context.bbSpace.gapV(BbSpaceToken.lg),
            TextButton(
              onPressed: _loadTransactions,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          '일치하는 거래가 없습니다',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.receipt_long,
              size: context.bbType.iconSm,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(
            tx.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${tx.transactionDate} | ${tx.category?.name ?? ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Text(
            '${CurrencyFormatter.format(tx.amount)}원',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          onTap: () => Navigator.of(context).pop(tx),
        );
      },
    );
  }
}
