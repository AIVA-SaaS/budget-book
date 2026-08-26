import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/features/card_settlement/presentation/card_settlement_route.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_state.dart';
import 'package:budget_book/core/widgets/reconciled_badge.dart';
import '../../../../core/theme/bb_scale.dart';

final _wonFormat = NumberFormat('#,###', 'ko');

class TransferListPage extends StatelessWidget {
  const TransferListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이체'),
      ),
      body: BlocConsumer<TransferBloc, TransferState>(
        listener: (context, state) {
          if (state is TransferError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is TransferLoaded &&
              state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is TransferLoaded &&
              state.operationSuccess != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.operationSuccess!)),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            TransferInitial() || TransferLoading() =>
              const SkeletonLoader(itemCount: 5),
            TransferLoaded() => _buildLoaded(context, state),
            TransferError() => _buildError(context),
          };
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transfers/create'),
        tooltip: '이체 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, TransferLoaded state) {
    return Column(
      children: [
        // MonthNavigator는 MonthCubit.state를 자동 watch
        const MonthNavigator(),
        // Total summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.swap_horiz,
                  size: context.bbType.iconSm,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '총 이체: ${_wonFormat.format(state.totalAmount)}원',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                '${state.transfers.length}건',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: state.transfers.isEmpty
              ? _buildEmpty(context)
              : _buildGroupedList(context, state),
        ),
      ],
    );
  }

  Widget _buildGroupedList(BuildContext context, TransferLoaded state) {
    final grouped = state.groupedByDate;
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      key: const PageStorageKey('transfer_list'),
      itemCount: sortedDates.length + 1,
      itemBuilder: (context, index) {
        if (index == sortedDates.length) return const SizedBox(height: 88);  // ui-fixed: FAB(56) 회피 — 스크롤 꼬리 여백
        final date = sortedDates[index];
        final transfers = grouped[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(dateStr: date),
            ...transfers.map((t) => _TransferListTile(
                  transfer: t,
                  onTap: () => context.push(transferEditRoute(t)),
                  onDelete: () => _confirmDelete(context, t),
                )),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Transfer transfer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이체 삭제'),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<TransferBloc>().add(DeleteTransfer(transfer.id));
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

  Widget _buildEmpty(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.swap_horiz,
      title: '이체 내역이 없습니다',
      subtitle: '결제수단 간 이체를 기록하세요',
      actionLabel: '이체 추가',
      onAction: () => context.push('/transfers/create'),
    );
  }

  Widget _buildError(BuildContext context) {
    final now = DateTime.now();
    return AppErrorWidget(
      message: '이체를 불러오지 못했습니다',
      onRetry: () {
        context.read<TransferBloc>().add(
              LoadTransfers(year: now.year, month: now.month),
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

class _TransferListTile extends StatelessWidget {
  final Transfer transfer;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _TransferListTile({
    required this.transfer,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(transfer.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete?.call();
        return false;
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.swap_horiz,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            // V65 — 거래 목록과 동일한 정산 배지 (이체 상세 진입 전에도 상태가 보이도록).
            if (transfer.isReconciled) ...[
              ReconciledBadge(seq: transfer.reconciliationSeq),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                transfer.sourcePaymentMethod.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_forward,
                size: context.bbType.iconSm,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Flexible(
              child: Text(
                transfer.destinationPaymentMethod.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: transfer.description != null && transfer.description!.isNotEmpty
            ? Text(
                transfer.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Text(
          '${_wonFormat.format(transfer.amount)}원',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
