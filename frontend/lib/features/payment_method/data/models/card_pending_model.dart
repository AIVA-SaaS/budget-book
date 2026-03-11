import 'package:budget_book/features/payment_method/domain/entities/card_pending.dart';
import 'payment_method_model.dart';

class CardPendingModel extends CardPending {
  const CardPendingModel({
    required super.paymentMethod,
    required super.pendingAmount,
    super.settlementDate,
    required super.transactionCount,
  });

  factory CardPendingModel.fromJson(Map<String, dynamic> json) {
    return CardPendingModel(
      paymentMethod: PaymentMethodModel.fromJson(
          json['paymentMethod'] as Map<String, dynamic>),
      pendingAmount: json['pendingAmount'] as int,
      settlementDate: json['settlementDate'] as String?,
      transactionCount: json['transactionCount'] as int,
    );
  }
}
