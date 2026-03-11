import 'package:equatable/equatable.dart';
import 'payment_method.dart';

class CardPending extends Equatable {
  final PaymentMethod paymentMethod;
  final int pendingAmount;
  final String? settlementDate;
  final int transactionCount;

  const CardPending({
    required this.paymentMethod,
    required this.pendingAmount,
    this.settlementDate,
    required this.transactionCount,
  });

  @override
  List<Object?> get props => [
        paymentMethod,
        pendingAmount,
        settlementDate,
        transactionCount,
      ];
}
