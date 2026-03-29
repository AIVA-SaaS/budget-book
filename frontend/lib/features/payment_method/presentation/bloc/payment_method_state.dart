import 'package:equatable/equatable.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/domain/entities/card_pending.dart';
import 'package:budget_book/features/payment_method/domain/entities/card_settlement_summary.dart';

sealed class PaymentMethodState extends Equatable {
  const PaymentMethodState();

  @override
  List<Object?> get props => [];
}

class PaymentMethodInitial extends PaymentMethodState {
  const PaymentMethodInitial();
}

class PaymentMethodLoading extends PaymentMethodState {
  const PaymentMethodLoading();
}

class PaymentMethodLoaded extends PaymentMethodState {
  final List<PaymentMethod> paymentMethods;
  final List<CardPending>? cardPendings;
  final CardSettlementSummary? cardSettlementSummary;
  final String? operationError;

  const PaymentMethodLoaded(
    this.paymentMethods, {
    this.cardPendings,
    this.cardSettlementSummary,
    this.operationError,
  });

  static int _typeOrder(String type) {
    switch (type) {
      case 'CASH':
        return 0;
      case 'BANK':
        return 1;
      case 'DEBIT':
        return 2;
      case 'CREDIT':
        return 3;
      default:
        return 4;
    }
  }

  List<PaymentMethod> get activePaymentMethods =>
      paymentMethods.where((pm) => pm.isActive).toList()
        ..sort((a, b) {
          final typeCompare = _typeOrder(a.type).compareTo(_typeOrder(b.type));
          if (typeCompare != 0) return typeCompare;
          return a.displayOrder.compareTo(b.displayOrder);
        });

  List<PaymentMethod> get creditCards =>
      paymentMethods.where((pm) => pm.isCredit).toList();

  @override
  List<Object?> get props =>
      [paymentMethods, cardPendings, cardSettlementSummary, operationError];
}

class PaymentMethodError extends PaymentMethodState {
  final String message;

  const PaymentMethodError(this.message);

  @override
  List<Object?> get props => [message];
}
