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

  List<PaymentMethod> get activePaymentMethods =>
      paymentMethods.where((pm) => pm.isActive).toList();

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
