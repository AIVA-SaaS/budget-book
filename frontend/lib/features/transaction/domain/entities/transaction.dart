import 'package:equatable/equatable.dart';
import 'transaction_author.dart';
import 'transaction_category.dart';

class Transaction extends Equatable {
  final String id;
  final String coupleId;
  final TransactionAuthor author;
  final TransactionCategory? category;
  final String type;
  final int amount;
  final String description;
  final String? memo;
  final String transactionDate;
  final String? paymentMethodId;
  final String? paymentMethodName;
  final String? paymentMethodType;
  final String? settlementDate;
  final String? pocketId;
  final String? pocketName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    required this.id,
    required this.coupleId,
    required this.author,
    this.category,
    required this.type,
    required this.amount,
    required this.description,
    this.memo,
    required this.transactionDate,
    this.paymentMethodId,
    this.paymentMethodName,
    this.paymentMethodType,
    this.settlementDate,
    this.pocketId,
    this.pocketName,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == 'INCOME';
  bool get isExpense => type == 'EXPENSE';

  @override
  List<Object?> get props => [
        id,
        coupleId,
        author,
        category,
        type,
        amount,
        description,
        memo,
        transactionDate,
        paymentMethodId,
        paymentMethodName,
        paymentMethodType,
        settlementDate,
        pocketId,
        pocketName,
        createdAt,
        updatedAt,
      ];
}
