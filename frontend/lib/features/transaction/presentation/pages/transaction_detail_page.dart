import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/dialog_helpers.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import '../../../../core/theme/bb_scale.dart';

class TransactionDetailPage extends StatelessWidget {
  final String transactionId;

  const TransactionDetailPage({super.key, required this.transactionId});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '복사',
            onPressed: () {
              final state = context.read<TransactionBloc>().state;
              if (state is TransactionLoaded) {
                final txn = _findTransaction(state);
                if (txn != null) {
                  // 배치 4 D-4 (2026-04-26): state.extra 새로고침 유실 fix —
                  // copyFromId query param 으로 전달, form page 가 fetch.
                  context.push('/transactions/create?copyFromId=${txn.id}');
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '수정',
            onPressed: () =>
                context.push('/transactions/edit/$transactionId'),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '삭제',
            onPressed: () => _showDeleteConfirm(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transactions/create'),
        tooltip: '거래 추가',
        child: const Icon(Icons.add),
      ),
      body: BlocListener<TransactionBloc, TransactionState>(
        listenWhen: (previous, current) {
          return current is TransactionLoaded &&
              current.operationSuccess != null;
        },
        listener: (context, state) {
          if (state is TransactionLoaded && state.operationSuccess != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.operationSuccess!)),
            );
            context.go('/transactions?year=${state.year}&month=${state.month}');
          }
        },
        child: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state is TransactionLoaded) {
            final txn = _findTransaction(state);
            if (txn != null) {
              return _buildContent(context, txn);
            }
          }
          // Fallback: load transaction directly from API
          return _AsyncTransactionLoader(
            transactionId: transactionId,
            bloc: context.read<TransactionBloc>(),
            builder: (txn) => _buildContent(context, txn),
          );
        },
      ),
      ),
    );
  }

  Transaction? _findTransaction(TransactionLoaded state) {
    try {
      return state.transactions.firstWhere((t) => t.id == transactionId);
    } catch (_) {
      return null;
    }
  }

  Widget _buildContent(BuildContext context, Transaction txn) {
    final theme = Theme.of(context);
    final isExpense = txn.isExpense;
    final isAdjustment = txn.isAdjustment;
    // 회차 5 — ADJUSTMENT 는 signed amount. 부호별 색/prefix/라벨/아이콘 분기.
    // (transaction_list_tile.dart 와 동일 정책)
    final Color amountColor;
    final String amountPrefix;
    final String typeLabel;
    final IconData typeIcon;
    if (isAdjustment) {
      final isIncrease = txn.amount >= 0;
      amountColor =
          isIncrease ? Colors.green.shade700 : Colors.red.shade700;
      amountPrefix = isIncrease ? '+' : '-';
      typeLabel = isIncrease ? '잔액 증가' : '잔액 감소';
      typeIcon = isIncrease ? Icons.tune : Icons.tune;
    } else if (isExpense) {
      amountColor = Colors.red;
      amountPrefix = '-';
      typeLabel = '지출';
      typeIcon = Icons.arrow_downward;
    } else {
      amountColor = Colors.blue;
      amountPrefix = '+';
      typeLabel = '수입';
      typeIcon = Icons.arrow_upward;
    }
    final displayAmount = txn.amount.abs();
    final category = txn.category;

    String formattedDate;
    try {
      final date = DateTime.parse(txn.transactionDate);
      formattedDate = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date);
    } catch (_) {
      formattedDate = txn.transactionDate;
    }

    String formattedCreatedAt;
    try {
      formattedCreatedAt =
          DateFormat('yyyy-MM-dd HH:mm').format(txn.createdAt);
    } catch (_) {
      formattedCreatedAt = txn.createdAt.toString();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
      children: [
        // Amount card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  typeIcon,
                  size: 36,
                  color: amountColor,
                ),
                context.bbSpace.gapV(BbSpaceToken.lg),
                Text(
                  typeLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: amountColor,
                  ),
                ),
                context.bbSpace.gapV(BbSpaceToken.xs),
                Text(
                  '$amountPrefix${CurrencyFormatter.format(displayAmount)}원',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        context.bbSpace.gapV(BbSpaceToken.xxl),

        // Details
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.description,
                  label: '내용',
                  value: txn.description,
                ),
                const Divider(height: 24),
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: '날짜',
                  value: formattedDate,
                ),
                const Divider(height: 24),
                // Category with icon and color
                _DetailRow(
                  icon: UIHelpers.resolveIcon(category?.icon),
                  iconColor: UIHelpers.parseColor(category?.color),
                  label: '카테고리',
                  value: category?.displayName ?? '미분류',
                ),
                if (txn.paymentMethodName != null) ...[
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.payment,
                    label: '결제수단',
                    value: txn.paymentMethodName!,
                  ),
                ],
                if (txn.pocketName != null) ...[
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.account_balance_wallet,
                    label: '포켓',
                    value: txn.pocketName!,
                  ),
                ],
                if (txn.memo != null && txn.memo!.isNotEmpty) ...[
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.note,
                    label: '메모',
                    value: txn.memo!,
                  ),
                ],
                // V65 — 정산 상태. 미기록이면 행 자체를 표시하지 않는다.
                if (txn.isReconciled) ...[
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.check_circle,
                    iconColor: const Color(0xFF2E7D32),
                    label: '정산',
                    value: [
                      '${txn.reconciliationSeq ?? '-'}차',
                      if (txn.reconciledAt != null)
                        DateFormat('M월 d일 HH:mm').format(txn.reconciledAt!),
                    ].join(' · '),
                  ),
                ],
                const Divider(height: 24),
                _DetailRow(
                  icon: Icons.person,
                  label: '작성자',
                  value: txn.author.nickname,
                ),
                const Divider(height: 24),
                _DetailRow(
                  icon: Icons.access_time,
                  label: '등록일시',
                  value: formattedCreatedAt,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirm(BuildContext context) async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: '거래 삭제',
    );
    if (confirmed && context.mounted) {
      context
          .read<TransactionBloc>()
          .add(DeleteTransaction(transactionId));
    }
  }

}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: iconColor ??
              theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Loads a single transaction from the API when the BLoC state doesn't contain it.
class _AsyncTransactionLoader extends StatefulWidget {
  final String transactionId;
  final TransactionBloc bloc;
  final Widget Function(Transaction) builder;

  const _AsyncTransactionLoader({
    required this.transactionId,
    required this.bloc,
    required this.builder,
  });

  @override
  State<_AsyncTransactionLoader> createState() => _AsyncTransactionLoaderState();
}

class _AsyncTransactionLoaderState extends State<_AsyncTransactionLoader> {
  Transaction? _transaction;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await widget.bloc.transactionRepository.getTransaction(widget.transactionId);
      if (!mounted) return;
      result.fold(
        (failure) => setState(() { _error = failure.message; _loading = false; }),
        (txn) => setState(() { _transaction = txn; _loading = false; }),
      );
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_transaction != null) return widget.builder(_transaction!);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
          context.bbSpace.gapV(BbSpaceToken.xl),
          Text(_error ?? '거래를 찾을 수 없습니다'),
        ],
      ),
    );
  }
}
