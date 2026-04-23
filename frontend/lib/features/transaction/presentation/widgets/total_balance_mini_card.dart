import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';

/// Phase 23 PR-X5: Single-line total balance (총자산) mini card.
///
/// Sum = (non-credit active balances) - (credit unpaid/pending amount).
/// Falls back to only summing non-credit balances when settlement data
/// is unavailable. Tapping navigates to the asset management page.
class TotalBalanceMiniCard extends StatelessWidget {
  const TotalBalanceMiniCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
      bloc: getIt<PaymentMethodBloc>(),
      builder: (context, state) {
        if (state is! PaymentMethodLoaded) return const SizedBox.shrink();
        return _buildCard(context, state);
      },
    );
  }

  Widget _buildCard(BuildContext context, PaymentMethodLoaded state) {
    final theme = Theme.of(context);
    final active = state.paymentMethods.where((pm) => pm.isActive).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    int assetsSum = 0;
    for (final pm in active) {
      if (pm.isCredit) continue;
      if (pm.balance != null) assetsSum += pm.balance!;
    }

    int creditUnpaid = 0;
    final settlement = state.cardSettlementSummary;
    if (settlement?.unpaidMonth != null) {
      creditUnpaid = settlement!.unpaidMonth!.totalAmount;
    }

    final total = assetsSum - creditUnpaid;

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => context.push('/asset-management'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '총 자산',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              Text(
                CurrencyFormatter.formatWithSign(total),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: total >= 0
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
