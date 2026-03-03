import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';

class TransactionCategoryModel extends TransactionCategory {
  const TransactionCategoryModel({
    required super.id,
    required super.name,
    required super.type,
    super.icon,
    super.color,
  });

  factory TransactionCategoryModel.fromJson(Map<String, dynamic> json) {
    return TransactionCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
    );
  }
}
