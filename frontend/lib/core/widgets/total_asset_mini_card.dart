import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';

/// Phase 25 Step 6 — 거래 탭 상단 총잔액 미니카드.
///
/// 데이터 출처: `asset_management_page.dart` `_AssetSummaryHeader` 와 동일 로직.
/// - 총자산: CASH / DEBIT / BANK 의 balance 합계 (null → 0)
/// 추가 API 호출 없이 `PaymentMethodBloc` 프리로드 상태를 재사용한다.
/// 탭 시 `/assets` 로 이동한다 (자산 탭으로 전환).
class TotalAssetMiniCard extends StatelessWidget {
  const TotalAssetMiniCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
      builder: (context, state) {
        if (state is! PaymentMethodLoaded) {
          return const SizedBox(height: 48);
        }

        final totalAsset = state.paymentMethods
            .where((pm) => pm.isActive && (pm.isCash || pm.isDebit || pm.isBank))
            .fold<int>(0, (sum, pm) => sum + (pm.balance ?? 0));

        final theme = Theme.of(context);
        final bg = Colors.green.withValues(alpha: 0.08);
        final fg = Colors.green.shade700;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => context.go('/assets'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, size: 18, color: fg),
                    const SizedBox(width: 8),
                    Text(
                      '총 자산',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${CurrencyFormatter.format(totalAsset)}원',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
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
          ),
        );
      },
    );
  }
}
