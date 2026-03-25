import 'package:budget_book/features/payment_method/domain/entities/card_settlement_summary.dart';

class CardSettlementSummaryModel extends CardSettlementSummary {
  const CardSettlementSummaryModel({
    required super.previousMonth,
    required super.currentMonth,
  });

  factory CardSettlementSummaryModel.fromJson(Map<String, dynamic> json) {
    return CardSettlementSummaryModel(
      previousMonth: CardSettlementMonthModel.fromJson(
          json['previousMonth'] as Map<String, dynamic>),
      currentMonth: CardSettlementMonthModel.fromJson(
          json['currentMonth'] as Map<String, dynamic>),
    );
  }
}

class CardSettlementMonthModel extends CardSettlementMonth {
  const CardSettlementMonthModel({
    required super.year,
    required super.month,
    required super.totalAmount,
    required super.cards,
  });

  factory CardSettlementMonthModel.fromJson(Map<String, dynamic> json) {
    final cardsList = json['cards'] as List<dynamic>;
    return CardSettlementMonthModel(
      year: json['year'] as int,
      month: json['month'] as int,
      totalAmount: json['totalAmount'] as int,
      cards: cardsList
          .map((e) =>
              CardSettlementCardModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CardSettlementCardModel extends CardSettlementCard {
  const CardSettlementCardModel({
    required super.paymentMethodId,
    required super.paymentMethodName,
    required super.amount,
    super.settlementDate,
    required super.transactionCount,
  });

  factory CardSettlementCardModel.fromJson(Map<String, dynamic> json) {
    return CardSettlementCardModel(
      paymentMethodId: json['paymentMethodId'] as String,
      paymentMethodName: json['paymentMethodName'] as String,
      amount: json['amount'] as int,
      settlementDate: json['settlementDate'] as String?,
      transactionCount: json['transactionCount'] as int,
    );
  }
}
