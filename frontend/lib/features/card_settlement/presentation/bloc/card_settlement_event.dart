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

  /// 편집 모드: 이 정산에 이미 묶인 거래도 함께 조회하고 pre-select 한다.
  final String? settlementTransferId;

  const LoadSettlement({
    required this.paymentMethodId,
    required this.year,
    required this.month,
    this.settlementTransferId,
  });

  @override
  List<Object?> get props =>
      [paymentMethodId, year, month, settlementTransferId];
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

class UpdateSettlement extends CardSettlementEvent {
  final String transferId;
  final String sourcePaymentMethodId;
  final String destinationPaymentMethodId;
  final int amount;
  final String date;
  final String? description;
  final List<String> transactionIds; // 새로 정산에 묶을 거래 ID 목록

  const UpdateSettlement({
    required this.transferId,
    required this.sourcePaymentMethodId,
    required this.destinationPaymentMethodId,
    required this.amount,
    required this.date,
    this.description,
    this.transactionIds = const [],
  });

  @override
  List<Object?> get props => [
        transferId,
        sourcePaymentMethodId,
        destinationPaymentMethodId,
        amount,
        date,
        description,
        transactionIds,
      ];
}
