import 'package:budget_book/features/card_settlement/domain/entities/settlement_transaction.dart';

class SettlementTransactionModel extends SettlementTransaction {
  const SettlementTransactionModel({
    required super.id,
    required super.transactionDate,
    super.settlementDate,
    required super.description,
    required super.amount,
    super.categoryName,
    super.categoryIcon,
    super.type,
  });

  factory SettlementTransactionModel.fromJson(Map<String, dynamic> json) {
    return SettlementTransactionModel(
      id: json['id'] as String,
      transactionDate: json['transactionDate'] as String,
      settlementDate: json['settlementDate'] as String?,
      description: json['description'] as String,
      amount: json['amount'] as int,
      categoryName: json['categoryName'] as String?,
      categoryIcon: json['categoryIcon'] as String?,
      type: json['type'] as String? ?? 'TRANSACTION',
    );
  }
}

class SettlementTransactionsResponseModel
    extends SettlementTransactionsResponse {
  const SettlementTransactionsResponseModel({
    required super.totalAmount,
    required super.transactionCount,
    required super.transactions,
  });

  factory SettlementTransactionsResponseModel.fromJson(
      Map<String, dynamic> json) {
    final txList = (json['transactions'] as List<dynamic>?)
            ?.map((e) => SettlementTransactionModel.fromJson(
                e as Map<String, dynamic>))
            .toList() ??
        [];
    return SettlementTransactionsResponseModel(
      totalAmount: json['totalAmount'] as int? ?? 0,
      transactionCount: json['transactionCount'] as int? ?? 0,
      transactions: txList,
    );
  }
}
