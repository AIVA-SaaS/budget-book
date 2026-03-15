import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/payment_method_form_sheet.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/card_pending_summary.dart';
import 'package:budget_book/core/widgets/error_widget.dart';

class PaymentMethodPage extends StatelessWidget {
  const PaymentMethodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('결제수단 관리'),
      ),
      body: BlocConsumer<PaymentMethodBloc, PaymentMethodState>(
        listener: (context, state) {
          if (state is PaymentMethodError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is PaymentMethodLoaded &&
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '등록된 결제수단이 없습니다',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Card pending summary at the top if there are credit cards
        if (methods.any((pm) => pm.isCredit))
          BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
            builder: (context, state) {
              if (state is PaymentMethodLoaded &&
                  state.cardPendings != null &&
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
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(method.type).withValues(alpha: 0.15),
          child: Icon(
            _getTypeIcon(method.type),
            color: _getTypeColor(method.type),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(method.name),
            const SizedBox(width: 8),
            _buildTypeBadge(context, method.type),
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
        subtitle: method.isCredit
            ? Text(
                '결제일: ${method.settlementDay ?? '-'}일, 마감일: ${method.closingDay ?? '-'}일',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              )
            : method.isDefault
                ? Text(
                    '기본 결제수단',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  )
                : null,
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
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showEditPaymentMethod(context, method),
              tooltip: '수정',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context, String type) {
    final label = switch (type) {
      'CASH' => '현금',
      'DEBIT' => '체크',
      'CREDIT' => '신용',
      _ => type,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getTypeColor(type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _getTypeColor(type),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    return switch (type) {
      'CASH' => Icons.money,
      'DEBIT' => Icons.credit_card,
      'CREDIT' => Icons.account_balance,
      _ => Icons.payment,
    };
  }

  Color _getTypeColor(String type) {
    return switch (type) {
      'CASH' => Colors.green,
      'DEBIT' => Colors.blue,
      'CREDIT' => Colors.deepPurple,
      _ => Colors.grey,
    };
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
      builder: (_) => PaymentMethodFormSheet(
        onSubmit: (name, type, settlementDay, closingDay) {
          bloc.add(CreatePaymentMethod(
            name: name,
            type: type,
            settlementDay: settlementDay,
            closingDay: closingDay,
          ));
        },
      ),
    );
  }

  void _showEditPaymentMethod(
      BuildContext context, PaymentMethod method) {
    final bloc = context.read<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaymentMethodFormSheet(
        paymentMethod: method,
        onSubmit: (name, type, settlementDay, closingDay) {
          bloc.add(UpdatePaymentMethod(
            id: method.id,
            name: name,
            settlementDay: settlementDay,
            closingDay: closingDay,
          ));
        },
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
