import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/utils/payment_method_helpers.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';

/// Payment method multi-select trigger for use within filter sheets.
///
/// PR-C3: `DropdownButtonFormField` → `ItemSelectorField` + `ItemSelectorSheet(multi)`.
/// 즐겨찾기 + 타입(현금/은행/체크/신용) 그룹 헤더 + 타입별 아이콘/색상을
/// 거래 폼과 동일한 패턴으로 제공한다.
class PaymentMethodFilter extends StatelessWidget {
  final Set<String> selectedIds;
  final String? displayLabel;
  final void Function(Set<String> ids) onChanged;

  const PaymentMethodFilter({
    super.key,
    this.selectedIds = const {},
    this.displayLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
      bloc: getIt<PaymentMethodBloc>(),
      builder: (context, pmState) {
        final methods = pmState is PaymentMethodLoaded
            ? pmState.activePaymentMethods
            : <PaymentMethod>[];

        // Group by type, then sort groups using paymentMethodGroupLabels order
        // so the sheet renders grouped sections consistently.
        final typeOrder = paymentMethodGroupLabels.keys.toList();
        final sorted = [...methods]..sort((a, b) {
            final ai = typeOrder.indexOf(a.type);
            final bi = typeOrder.indexOf(b.type);
            final aIdx = ai == -1 ? typeOrder.length : ai;
            final bIdx = bi == -1 ? typeOrder.length : bi;
            if (aIdx != bIdx) return aIdx.compareTo(bIdx);
            return a.name.compareTo(b.name);
          });

        final items = <SelectorItem>[
          for (var i = 0; i < sorted.length; i++)
            SelectorItem(
              id: sorted[i].id,
              label: sorted[i].name,
              leadingIcon: paymentMethodTypeIcon(sorted[i].type),
              leadingColor: paymentMethodTypeColor(context, sorted[i].type),
              isDeletable: false,
              displayOrder: i,
              group: sorted[i].type,
            ),
        ];

        return ItemSelectorField(
          label: '결제수단',
          selectedLabel: displayLabel,
          prefixIcon: Icons.account_balance_wallet,
          placeholder: '전체',
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => ItemSelectorSheet(
                mode: SelectionMode.multi,
                title: '결제수단 선택',
                items: items,
                initialSelectedIds: selectedIds,
                favoriteType: 'PAYMENT_METHOD',
                groupLabels: paymentMethodGroupLabels,
                onSelected: (_) {},
                onApplyMulti: (ids) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onChanged(ids);
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Resolve payment method name from ID using the BLoC state.
  static String? resolveName(String pmId) {
    final pmState = getIt<PaymentMethodBloc>().state;
    if (pmState is PaymentMethodLoaded) {
      final match =
          pmState.paymentMethods.where((pm) => pm.id == pmId).firstOrNull;
      return match?.name;
    }
    return null;
  }
}

/// Pocket multi-select trigger for use within filter sheets.
///
/// PR-C3: 포켓은 그룹 개념이 없으므로 `groupLabels` 없이 단순 multi 목록.
class PocketFilter extends StatelessWidget {
  final Set<String> selectedIds;
  final String? displayLabel;
  final void Function(Set<String> ids) onChanged;

  const PocketFilter({
    super.key,
    this.selectedIds = const {},
    this.displayLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PocketBloc, PocketState>(
      bloc: getIt<PocketBloc>(),
      builder: (context, pocketState) {
        final pockets = pocketState is PocketLoaded
            ? pocketState.activePockets
            : <MoneyPocket>[];

        final items = <SelectorItem>[
          for (var i = 0; i < pockets.length; i++)
            SelectorItem(
              id: pockets[i].id,
              label: pockets[i].name,
              leadingIcon: Icons.savings,
              leadingColor: Colors.orange,
              isDeletable: false,
              displayOrder: i,
            ),
        ];

        return ItemSelectorField(
          label: '포켓',
          selectedLabel: displayLabel,
          prefixIcon: Icons.savings,
          placeholder: '전체',
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => ItemSelectorSheet(
                mode: SelectionMode.multi,
                title: '포켓 선택',
                items: items,
                initialSelectedIds: selectedIds,
                onSelected: (_) {},
                onApplyMulti: (ids) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onChanged(ids);
                  });
                },
              ),
            );
          },
        );
      },
    );
  }
}
