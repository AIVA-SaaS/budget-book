import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/utils/payment_method_helpers.dart';
import 'package:budget_book/core/widgets/balance_adjustment_sheet.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';

class AccountBalanceCard extends StatelessWidget {
  final bool showHeader;

  const AccountBalanceCard({super.key, this.showHeader = true});

  @override
  Widget build(BuildContext context) {
    // PaymentMethodBloc state 변경 시 자동 rebuild — 월 변경/결제/잔액 수정 반영
    return BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
      bloc: getIt<PaymentMethodBloc>(),
      builder: (context, pmState) {
        if (pmState is! PaymentMethodLoaded) return const SizedBox.shrink();
        return _buildContent(context, pmState);
      },
    );
  }

  Widget _buildContent(BuildContext context, PaymentMethodLoaded pmState) {
    final methods = pmState.paymentMethods.where((pm) => pm.isActive).toList();
    if (methods.isEmpty) return const SizedBox.shrink();

    final cashMethods = methods.where((pm) => pm.isCash).toList();
    final bankDebitMethods = methods.where((pm) => pm.isBank || pm.isDebit).toList();
    final creditMethods = methods.where((pm) => pm.isCredit).toList();
    final settlement = pmState.cardSettlementSummary;
    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('자산 현황', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => context.push('/payment-methods'), child: const Text('관리')),
            ],
          ),
          const SizedBox(height: 8),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('자산 현황', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
        if (cashMethods.isNotEmpty)
          _AssetGroup(label: '현금', icon: Icons.money, color: Colors.green,
              methods: cashMethods, settlement: settlement),
        if (bankDebitMethods.isNotEmpty)
          _AssetGroup(label: '은행 / 체크', icon: Icons.account_balance, color: Colors.blue,
              methods: bankDebitMethods, settlement: settlement),
        if (creditMethods.isNotEmpty)
          _AssetGroup(label: '카드', icon: Icons.credit_card, color: Colors.purple,
              methods: creditMethods, settlement: settlement),
      ],
    );

    if (showHeader) {
      return Card(
        child: Padding(padding: const EdgeInsets.all(16), child: content),
      );
    }
    return Padding(padding: const EdgeInsets.fromLTRB(12, 16, 12, 8), child: content);
  }
}

class _AssetGroup extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<dynamic> methods;
  final dynamic settlement;

  const _AssetGroup({
    required this.label,
    required this.icon,
    required this.color,
    required this.methods,
    this.settlement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ...methods.map((pm) => _AssetItem(pm: pm, settlement: settlement)),
        ],
      ),
    );
  }
}

class _AssetItem extends StatelessWidget {
  final dynamic pm;
  final dynamic settlement;

  const _AssetItem({required this.pm, this.settlement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = pm.isCredit as bool;

    int prevAmount = 0;
    int currAmount = 0;
    int unpaidAmount = 0;
    if (isCredit && settlement != null) {
      try {
        final prevCard = settlement.previousMonth.cards.where((c) => c.paymentMethodId == pm.id);
        if (prevCard.isNotEmpty) prevAmount = prevCard.first.amount as int;
        final currCard = settlement.currentMonth.cards.where((c) => c.paymentMethodId == pm.id);
        if (currCard.isNotEmpty) currAmount = currCard.first.amount as int;
        // 미결제: buildMonthBySettlementDate (paid_at IS NULL 필터 적용됨)
        if (settlement.unpaidMonth != null) {
          final unpaidCard = settlement.unpaidMonth.cards.where((c) => c.paymentMethodId == pm.id);
          if (unpaidCard.isNotEmpty) unpaidAmount = unpaidCard.first.amount as int;
        }
      } catch (_) {}
    }

    return InkWell(
      onTap: () => context.push(
        '/transactions?paymentMethodId=${pm.id}&paymentMethodName=${Uri.encodeComponent(pm.name as String)}',
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Row(
          children: [
            Icon(paymentMethodTypeIcon(pm.type as String), size: 16,
                color: paymentMethodTypeColor(pm.type as String)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(pm.name as String,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            ),
            if (!isCredit) ...[
              Text(
                pm.balance != null ? CurrencyFormatter.formatWithSign(pm.balance as int) : '-',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: pm.balance != null && (pm.balance as int) >= 0
                        ? Colors.green.shade800 : Colors.red.shade800),
              ),
              if (pm.balance != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    icon: Icon(Icons.tune, size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    padding: EdgeInsets.zero,
                    tooltip: '잔액 수정',
                    onPressed: () => BalanceAdjustmentSheet.show(
                      context,
                      paymentMethodId: pm.id as String,
                      paymentMethodName: pm.name as String,
                      currentBalance: pm.balance as int,
                    ),
                  ),
                ),
            ],
            if (isCredit)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _chip('전월', CurrencyFormatter.format(prevAmount),
                        Colors.grey.shade200, context, textColor: Colors.grey.shade800),
                    const SizedBox(width: 3),
                    _chip('미결제', CurrencyFormatter.format(unpaidAmount),
                        unpaidAmount > 0 ? Colors.red.shade50 : Colors.green.shade50, context,
                        textColor: unpaidAmount > 0 ? Colors.red.shade800 : Colors.green.shade800),
                  ]),
                  const SizedBox(height: 2),
                  _chip('이번달', CurrencyFormatter.format(currAmount),
                      Colors.blue.shade50, context, textColor: Colors.blue.shade800),
                ],
              ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color bg, BuildContext context, {Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label $value원',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: textColor ?? Theme.of(context).colorScheme.onSurface)),
    );
  }
}
