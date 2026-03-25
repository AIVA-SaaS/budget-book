import 'package:equatable/equatable.dart';

class CardSettlementSummary extends Equatable {
  final CardSettlementMonth previousMonth;
  final CardSettlementMonth currentMonth;

  const CardSettlementSummary({
    required this.previousMonth,
    required this.currentMonth,
  });

  @override
  List<Object?> get props => [previousMonth, currentMonth];
}

class CardSettlementMonth extends Equatable {
  final int year;
  final int month;
  final int totalAmount;
  final List<CardSettlementCard> cards;

  const CardSettlementMonth({
    required this.year,
    required this.month,
    required this.totalAmount,
    required this.cards,
  });

  @override
  List<Object?> get props => [year, month, totalAmount, cards];
}

class CardSettlementCard extends Equatable {
  final String paymentMethodId;
  final String paymentMethodName;
  final int amount;
  final String? settlementDate;
  final int transactionCount;

  const CardSettlementCard({
    required this.paymentMethodId,
    required this.paymentMethodName,
    required this.amount,
    this.settlementDate,
    required this.transactionCount,
  });

  @override
  List<Object?> get props => [
        paymentMethodId,
        paymentMethodName,
        amount,
        settlementDate,
        transactionCount,
      ];
}
