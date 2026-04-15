import 'package:equatable/equatable.dart';

sealed class CardSettlementEvent extends Equatable {
  const CardSettlementEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettlement extends CardSettlementEvent {
  final String paymentMethodId;
  final int year;
  final int month;

  const LoadSettlement({
    required this.paymentMethodId,
    required this.year,
    required this.month,
  });

  @override
  List<Object?> get props => [paymentMethodId, year, month];
}

class ToggleTransaction extends CardSettlementEvent {
  final String transactionId;

  const ToggleTransaction(this.transactionId);

  @override
  List<Object?> get props => [transactionId];
}

class ToggleAllTransactions extends CardSettlementEvent {
  final bool selected;

  const ToggleAllTransactions(this.selected);

  @override
  List<Object?> get props => [selected];
}

class UpdateCustomAmount extends CardSettlementEvent {
  final int? amount;

  const UpdateCustomAmount(this.amount);

  @override
  List<Object?> get props => [amount];
}

class SubmitSettlement extends CardSettlementEvent {
  final String sourcePaymentMethodId;
  final String destinationPaymentMethodId;
  final int amount;
  final String date;
  final String? description;
  final List<String> transactionIds; // 결제 처리할 거래 ID 목록

  const SubmitSettlement({
    required this.sourcePaymentMethodId,
    required this.destinationPaymentMethodId,
    required this.amount,
    required this.date,
    this.description,
    this.transactionIds = const [],
  });

  @override
  List<Object?> get props => [
        sourcePaymentMethodId,
        destinationPaymentMethodId,
        amount,
        date,
        description,
        transactionIds,
      ];
}
