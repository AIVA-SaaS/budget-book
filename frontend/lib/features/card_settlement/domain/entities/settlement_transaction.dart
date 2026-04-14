import 'package:equatable/equatable.dart';

class SettlementTransactionsResponse extends Equatable {
  final int totalAmount;
  final int transactionCount;
  final List<SettlementTransaction> transactions;

  const SettlementTransactionsResponse({
    required this.totalAmount,
    required this.transactionCount,
    required this.transactions,
  });

  @override
  List<Object?> get props => [totalAmount, transactionCount, transactions];
}

class SettlementTransaction extends Equatable {
  final String id;
  final String transactionDate;
  final String? settlementDate;
  final String description;
  final int amount;
  final String? categoryName;
  final String? categoryIcon;

  const SettlementTransaction({
    required this.id,
    required this.transactionDate,
    this.settlementDate,
    required this.description,
    required this.amount,
    this.categoryName,
    this.categoryIcon,
  });

  @override
  List<Object?> get props => [
        id,
        transactionDate,
        settlementDate,
        description,
        amount,
        categoryName,
        categoryIcon,
      ];
}
