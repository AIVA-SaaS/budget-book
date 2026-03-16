import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';

class TransactionDetailPage extends StatelessWidget {
  final String transactionId;

  const TransactionDetailPage({super.key, required this.transactionId});

  static final _amountFormatter = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 상세'),
        actions: [
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
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state is! TransactionLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final txn = _findTransaction(state);
          if (txn == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  const Text('거래를 찾을 수 없습니다'),
                ],
              ),
            );
          }

          return _buildContent(context, txn);
        },
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
    final amountColor = isExpense ? Colors.red : Colors.blue;
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
      padding: const EdgeInsets.all(20),
      children: [
        // Amount card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 36,
                  color: amountColor,
                ),
                const SizedBox(height: 8),
                Text(
                  isExpense ? '지출' : '수입',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isExpense ? "-" : "+"}${_amountFormatter.format(txn.amount)}원',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

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
                  icon: _resolveIcon(category?.icon),
                  iconColor: _parseColor(category?.color),
                  label: '카테고리',
                  value: category?.name ?? '미분류',
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

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거래 삭제'),
        content: const Text('정말 이 거래를 삭제하시겠습니까?'),
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
                  .add(DeleteTransaction(transactionId));
              context.pop();
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

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    try {
      final colorStr = hex.replaceFirst('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _resolveIcon(String? iconName) {
    if (iconName == null) return Icons.receipt_long;
    const iconMap = <String, IconData>{
      'restaurant': Icons.restaurant,
      'restaurant_menu': Icons.restaurant_menu,
      'shopping_cart': Icons.shopping_cart,
      'directions_bus': Icons.directions_bus,
      'home': Icons.home,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'pets': Icons.pets,
      'payments': Icons.payments,
      'work': Icons.work,
      'savings': Icons.savings,
      'card_giftcard': Icons.card_giftcard,
      'trending_up': Icons.trending_up,
      'local_cafe': Icons.local_cafe,
      'movie': Icons.movie,
      'fitness_center': Icons.fitness_center,
      'child_care': Icons.child_care,
      'phone': Icons.phone,
      'electric_bolt': Icons.electric_bolt,
      'account_balance': Icons.account_balance,
    };
    return iconMap[iconName] ?? Icons.receipt_long;
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
