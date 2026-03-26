import 'package:equatable/equatable.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';

class PaymentMethodRef extends Equatable {
  final String id;
  final String name;
  final String type;

  const PaymentMethodRef({
    required this.id,
    required this.name,
    required this.type,
  });

  @override
  List<Object?> get props => [id, name, type];
}

class Transfer extends Equatable {
  final String id;
  final String coupleId;
  final TransactionAuthor author;
  final PaymentMethodRef sourcePaymentMethod;
  final PaymentMethodRef destinationPaymentMethod;
  final int amount;
  final String? description;
  final String? memo;
  final String transferDate;
  final DateTime createdAt;

  const Transfer({
    required this.id,
    required this.coupleId,
    required this.author,
    required this.sourcePaymentMethod,
    required this.destinationPaymentMethod,
    required this.amount,
    this.description,
    this.memo,
    required this.transferDate,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        coupleId,
        author,
        sourcePaymentMethod,
        destinationPaymentMethod,
        amount,
        description,
        memo,
        transferDate,
        createdAt,
      ];
}
