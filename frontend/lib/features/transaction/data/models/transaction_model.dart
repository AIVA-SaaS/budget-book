import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'transaction_author_model.dart';
import 'transaction_category_model.dart';

class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.coupleId,
    required super.author,
    super.category,
    required super.type,
    required super.amount,
    required super.description,
    super.memo,
    required super.transactionDate,
    required super.createdAt,
    required super.updatedAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      coupleId: json['coupleId'] as String,
      author: TransactionAuthorModel.fromJson(
          json['author'] as Map<String, dynamic>),
      category: json['category'] != null
          ? TransactionCategoryModel.fromJson(
              json['category'] as Map<String, dynamic>)
          : null,
      type: json['type'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String,
      memo: json['memo'] as String?,
      transactionDate: json['transactionDate'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
