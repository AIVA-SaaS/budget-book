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
    super.paymentMethodId,
    super.paymentMethodName,
    super.paymentMethodType,
    super.settlementDate,
    super.pocketId,
    super.pocketName,
    super.visibility,
    super.ownerId,
    super.needsReview,
    super.reconciliationId,
    super.reconciliationSeq,
    super.reconciledAt,
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
      paymentMethodId: json['paymentMethodId'] as String?,
      paymentMethodName: json['paymentMethodName'] as String?,
      paymentMethodType: json['paymentMethodType'] as String?,
      settlementDate: json['settlementDate'] as String?,
      pocketId: json['pocketId'] as String?,
      pocketName: json['pocketName'] as String?,
      visibility: json['visibility'] as String? ?? 'SHARED',
      ownerId: json['ownerId'] as String?,
      needsReview: json['needsReview'] as bool? ?? false,
      // V65 — 정산 스냅샷 (미기록이면 서버가 null 로 보낸다).
      reconciliationId: json['reconciliationId'] as String?,
      reconciliationSeq: json['reconciliationSeq'] as int?,
      reconciledAt: json['reconciledAt'] != null
          ? DateTime.parse(json['reconciledAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
