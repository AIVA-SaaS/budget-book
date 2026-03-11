import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/transaction/data/models/transaction_category_model.dart';

class CategoryStatisticsModel extends CategoryStatistics {
  const CategoryStatisticsModel({
    required super.category,
    required super.amount,
    required super.percentage,
    required super.transactionCount,
  });

  factory CategoryStatisticsModel.fromJson(Map<String, dynamic> json) {
    return CategoryStatisticsModel(
      category: TransactionCategoryModel.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
      amount: json['amount'] as int,
      percentage: (json['percentage'] as num).toDouble(),
      transactionCount: json['transactionCount'] as int,
    );
  }
}
