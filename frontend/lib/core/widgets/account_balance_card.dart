import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/theme/bb_colors.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/entity_group_header.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';
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
    final bankDebitMethods =
        methods.where((pm) => pm.isBank || pm.isDebit).toList();
    final creditMethods = methods.where((pm) => pm.isCredit).toList();
    final settlement = pmState.cardSettlementSummary;
    final theme = Theme.of(context);
    final space = context.bbSpace;

    // ★자산 탭과 **같은 구조**다 (2026-08-21): 평면 목록 + [EntityGroupHeader] +
    // `EntityTileRow` 직접. 예전에는 그룹마다 테두리 `Container`(padding 12 / margin 8)를
    // 직접 조립해 그룹 경계가 32dp 였고 자산 탭은 19dp 였다 — 같은 타일이 화면마다 다른
    // 리듬으로 보이던 원인이다. 좌우 여백도 헤더·타일이 소유하므로 여기서 감싸지 않는다.
    Iterable<Widget> group(
      String label,
      IconData icon,
      String typeKey,
      List<dynamic> items,
    ) =>
        items.isEmpty
            ? const <Widget>[]
            : <Widget>[
                EntityGroupHeader(
                  label: label,
                  icon: icon,
                  color: context.bb.paymentType(typeKey),
                ),
                ...items
                    .map((pm) => _AssetItem(pm: pm, settlement: settlement)),
              ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Padding(
            padding: space.only(
              left: BbSpaceToken.xl,
              right: BbSpaceToken.xl,
              bottom: BbSpaceToken.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('자산 현황',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(
                    onPressed: () => context.push('/payment-methods'),
                    child: const Text('관리')),
              ],
            ),
          )
        else
          Padding(
            padding: space.only(
              left: BbSpaceToken.xl,
              top: BbSpaceToken.md,
              right: BbSpaceToken.xl,
              bottom: BbSpaceToken.xs,
            ),
            child: Text('자산 현황',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ...group('현금', Icons.money, 'CASH', cashMethods),
        ...group('은행 / 체크', Icons.account_balance, 'BANK', bankDebitMethods),
        ...group('카드', Icons.credit_card, 'CREDIT', creditMethods),
      ],
    );

    if (showHeader) {
      return Card(
        child: Padding(
          padding: space.symmetric(v: BbSpaceToken.md),
          child: content,
        ),
      );
    }
    return content;
  }
}

class _AssetItem extends StatelessWidget {
  final dynamic pm;
  final dynamic settlement;

  const _AssetItem({required this.pm, this.settlement});

  @override
  Widget build(BuildContext context) {
    final isCredit = pm.isCredit as bool;

    int prevAmount = 0;
    int currAmount = 0;
    int unpaidAmount = 0;
    if (isCredit && settlement != null) {
      try {
        final prevCard = settlement.previousMonth.cards
            .where((c) => c.paymentMethodId == pm.id);
        if (prevCard.isNotEmpty) prevAmount = prevCard.first.amount as int;
        final currCard = settlement.currentMonth.cards
            .where((c) => c.paymentMethodId == pm.id);
        if (currCard.isNotEmpty) currAmount = currCard.first.amount as int;
        // 미결제: buildMonthBySettlementDate (paid_at IS NULL 필터 적용됨)
        if (settlement.unpaidMonth != null) {
          final unpaidCard = settlement.unpaidMonth.cards
              .where((c) => c.paymentMethodId == pm.id);
          if (unpaidCard.isNotEmpty) {
            unpaidAmount = unpaidCard.first.amount as int;
          }
        }
      } catch (_) {}
    }

    final balance = pm.balance as int?;

    return EntityTileRow(
      title: pm.name as String,
      leadingIcon: paymentMethodTypeIcon(pm.type as String),
      leadingColor: context.bb.paymentType(pm.type as String),
      trailingMetric: isCredit
          ? null
          : EntityMetric(
              value: balance != null
                  ? CurrencyFormatter.formatWithSign(balance)
                  : '-',
              tone: (balance ?? 0) >= 0
                  ? EntityTone.positive
                  : EntityTone.negative,
            ),
      metrics: isCredit
          ? [
              EntityMetric(
                  label: '전월',
                  value: '${CurrencyFormatter.format(prevAmount)}원'),
              EntityMetric(
                label: '미결제',
                value: '${CurrencyFormatter.format(unpaidAmount)}원',
                tone:
                    unpaidAmount > 0 ? EntityTone.expense : EntityTone.neutral,
              ),
              EntityMetric(
                label: '이번달',
                value: '${CurrencyFormatter.format(currAmount)}원',
                tone: EntityTone.income,
              ),
            ]
          : const [],
      onTap: () => context.push(
        '/transactions?paymentMethodId=${pm.id}&paymentMethodName=${Uri.encodeComponent(pm.name as String)}',
      ),
      // 이 화면에는 편집 모드가 없다 — 잔액 수정은 상시 노출 액션으로 유지한다.
      viewAction: (!isCredit && balance != null)
          ? EntityViewAction(
              icon: Icons.tune,
              tooltip: '잔액 수정',
              onPressed: () => BalanceAdjustmentSheet.show(
                context,
                paymentMethodId: pm.id as String,
                paymentMethodName: pm.name as String,
                currentBalance: balance,
              ),
            )
          : null,
    );
  }
}
