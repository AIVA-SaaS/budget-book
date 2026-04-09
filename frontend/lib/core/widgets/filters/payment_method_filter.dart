import 'package:flutter/material.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';

/// Payment method dropdown for use within filter sheets.
class PaymentMethodFilter extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const PaymentMethodFilter({
    super.key,
    this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pmBloc = getIt<PaymentMethodBloc>();
    final pmState = pmBloc.state;
    final methods = pmState is PaymentMethodLoaded
        ? pmState.activePaymentMethods
        : <PaymentMethod>[];

    return DropdownButtonFormField<String>(
      key: ValueKey('pm_filter_$selectedId'),
      initialValue: selectedId,
      decoration: const InputDecoration(
        labelText: '결제수단',
      ),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('전체'),
        ),
        ...methods.map((pm) => DropdownMenuItem<String>(
              value: pm.id,
              child: Text(pm.name),
            )),
      ],
      onChanged: onChanged,
    );
  }

  /// Resolve payment method name from ID using the BLoC state.
  static String? resolveName(String pmId) {
    final pmState = getIt<PaymentMethodBloc>().state;
    if (pmState is PaymentMethodLoaded) {
      final match = pmState.paymentMethods
          .where((pm) => pm.id == pmId)
          .firstOrNull;
      return match?.name;
    }
    return null;
  }
}

/// Pocket dropdown for use within filter sheets.
class PocketFilter extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const PocketFilter({
    super.key,
    this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pocketBloc = getIt<PocketBloc>();
    final pocketState = pocketBloc.state;
    final pockets = pocketState is PocketLoaded
        ? pocketState.activePockets
        : <MoneyPocket>[];

    return DropdownButtonFormField<String>(
      key: ValueKey('pocket_filter_$selectedId'),
      initialValue: selectedId,
      decoration: const InputDecoration(
        labelText: '포켓',
      ),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('전체'),
        ),
        ...pockets.map((p) => DropdownMenuItem<String>(
              value: p.id,
              child: Text(p.name),
            )),
      ],
      onChanged: onChanged,
    );
  }
}
