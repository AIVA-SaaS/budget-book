import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/utils/payment_method_helpers.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/payment_method_form_sheet.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/card_pending_summary.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';

class PaymentMethodPage extends StatelessWidget {
  const PaymentMethodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('결제수단 관리'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/transfers'),
            icon: const Icon(Icons.swap_horiz, size: 20),
            label: const Text('이체'),
          ),
        ],
      ),
      body: BlocConsumer<PaymentMethodBloc, PaymentMethodState>(
        listener: (context, state) {
          if (state is PaymentMethodError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is PaymentMethodLoaded &&
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
            PaymentMethodInitial() ||
            PaymentMethodLoading() =>
              const Center(child: CircularProgressIndicator()),
            PaymentMethodLoaded(
              paymentMethods: final methods,
              cardPendings: final pendings,
            ) =>
              _buildContent(context, methods, pendings != null),
            PaymentMethodError() => _buildError(context),
          };
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPaymentMethod(context),
        tooltip: '결제수단 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<PaymentMethod> methods,
    bool hasCardPendings,
  ) {
    if (methods.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.payment,
        title: '결제수단이 없습니다',
        subtitle: '등록된 결제수단이 없습니다',
        actionLabel: '결제수단 추가',
        onAction: () => _showAddPaymentMethod(context),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Card settlement summary at the top if there are credit cards
        if (methods.any((pm) => pm.isCredit))
          BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
            builder: (context, state) {
              if (state is! PaymentMethodLoaded) {
                return const SizedBox.shrink();
              }
              final summary = state.cardSettlementSummary;
              if (summary != null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: _buildCardSettlementSummary(context, summary),
                );
              }
              // Fallback to old card pending widget
              if (state.cardPendings != null &&
                  state.cardPendings!.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child:
                      CardPendingSummary(cardPendings: state.cardPendings!),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        // Payment method list
        ...methods.map((pm) => _buildPaymentMethodTile(context, pm)),
      ],
    );
  }

  Widget _buildPaymentMethodTile(
      BuildContext context, PaymentMethod method) {
    return Dismissible(
      key: Key(method.id),
      direction: method.isDefault
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: (_) => _showDeleteDialog(context, method),
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: paymentMethodTypeColor(method.type).withValues(alpha: 0.15),
          child: Icon(
            paymentMethodTypeIcon(method.type),
            color: paymentMethodTypeColor(method.type),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(method.name, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            buildPaymentMethodTypeBadge(context, method.type),
            if (!method.isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '비활성',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: _buildSubtitle(context, method),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: method.isActive,
              onChanged: (value) {
                context.read<PaymentMethodBloc>().add(
                      UpdatePaymentMethod(
                        id: method.id,
                        isActive: value,
                      ),
                    );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') {
                  _showEditPaymentMethod(context, method);
                } else if (action == 'delete') {
                  _showDeleteDialog(context, method);
                } else if (action == 'history') {
                  context.push('/transactions?paymentMethodId=${method.id}&paymentMethodName=${Uri.encodeComponent(method.name)}');
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'history',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, size: 20),
                      SizedBox(width: 8),
                      Text('내역 보기'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('수정'),
                    ],
                  ),
                ),
                if (!method.isDefault)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Text('삭제',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context, PaymentMethod method) {
    final subtitleStyle = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    );

    if (method.isCredit) {
      final parts = <String>[];
      parts.add(
          '마감일: ${method.closingDay == 31 ? '말일' : '${method.closingDay ?? '-'}일'}, 결제일: ${method.settlementDay ?? '-'}일');
      if (method.linkedBankName != null) {
        parts.add('결제은행: ${method.linkedBankName}');
      }
      return Text(parts.join('\n'), style: subtitleStyle);
    }

    // BANK, DEBIT, CASH — show balance
    if (method.balance != null) {
      final balanceText = CurrencyFormatter.formatWithSign(method.balance!);
      final color = method.balance! > 0
          ? Colors.green.shade700
          : method.balance! < 0
              ? Colors.red.shade700
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
      return Text(
        balanceText,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      );
    }

    if (method.isDefault) {
      return Text('기본 결제수단', style: subtitleStyle.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ));
    }

    return null;
  }

  Widget _buildCardSettlementSummary(
      BuildContext context, dynamic summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '카드 결제 현황',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSettlementMonthCard(
                    context,
                    '전월 결제',
                    summary.previousMonth.totalAmount as int,
                    summary.previousMonth.cards.length as int,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSettlementMonthCard(
                    context,
                    '이번달 결제',
                    summary.currentMonth.totalAmount as int,
                    summary.currentMonth.cards.length as int,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementMonthCard(
    BuildContext context,
    String label,
    int amount,
    int cardCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${CurrencyFormatter.format(amount)}원',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return AppErrorWidget(
      message: '결제수단을 불러오지 못했습니다',
      onRetry: () {
        context
            .read<PaymentMethodBloc>()
            .add(const LoadPaymentMethods());
      },
      showHomeButton: true,
    );
  }

  void _showAddPaymentMethod(BuildContext context) {
    final bloc = context.read<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: PaymentMethodFormSheet(
          onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
            bloc.add(CreatePaymentMethod(
              name: name,
              type: type,
              settlementDay: settlementDay,
              closingDay: closingDay,
              linkedBankId: linkedBankId,
            ));
          },
        ),
      ),
    );
  }

  void _showEditPaymentMethod(
      BuildContext context, PaymentMethod method) {
    final bloc = context.read<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: PaymentMethodFormSheet(
          paymentMethod: method,
          onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
            bloc.add(UpdatePaymentMethod(
              id: method.id,
              name: name,
              settlementDay: settlementDay,
              closingDay: closingDay,
              linkedBankId: linkedBankId,
              clearLinkedBank: linkedBankId == null && method.linkedBankId != null,
            ));
          },
        ),
      ),
    );
  }

  Future<bool> _showDeleteDialog(
      BuildContext context, PaymentMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('결제수단 삭제'),
        content:
            Text("'${method.name}' 결제수단을 삭제하시겠습니까?\n이 결제수단을 사용한 거래 기록은 유지됩니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<PaymentMethodBloc>().add(DeletePaymentMethod(method.id));
    }
    return confirmed ?? false;
  }
}
