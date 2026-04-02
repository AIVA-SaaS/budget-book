import 'package:equatable/equatable.dart';

class PaymentMethodStatistics extends Equatable {
  final String paymentMethodId;
  final String paymentMethodName;
  final String? paymentMethodType;
  final int totalAmount;
  final int transactionCount;
  final double percentage;
  final int? transferOut;
  final int? transferIn;

  const PaymentMethodStatistics({
    required this.paymentMethodId,
    required this.paymentMethodName,
    this.paymentMethodType,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentage,
    this.transferOut,
    this.transferIn,
  });

  @override
  List<Object?> get props => [
        paymentMethodId,
        paymentMethodName,
        paymentMethodType,
        totalAmount,
        transactionCount,
        percentage,
        transferOut,
        transferIn,
      ];
}
