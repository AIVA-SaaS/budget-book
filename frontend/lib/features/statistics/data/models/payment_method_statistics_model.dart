import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';

class PaymentMethodStatisticsModel extends PaymentMethodStatistics {
  const PaymentMethodStatisticsModel({
    required super.paymentMethodId,
    required super.paymentMethodName,
    super.paymentMethodType,
    required super.totalAmount,
    required super.transactionCount,
    required super.percentage,
    super.transferOut,
    super.transferIn,
  });

  factory PaymentMethodStatisticsModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodStatisticsModel(
      paymentMethodId: json['paymentMethodId'] as String? ?? '',
      paymentMethodName: json['paymentMethodName'] as String? ?? '미분류',
      paymentMethodType: json['paymentMethodType'] as String?,
      totalAmount: json['totalAmount'] as int? ?? 0,
      transactionCount: json['transactionCount'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      transferOut: json['transferOut'] as int?,
      transferIn: json['transferIn'] as int?,
    );
  }
}
