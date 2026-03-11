import 'package:equatable/equatable.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';

class CategoryStatistics extends Equatable {
  final TransactionCategory category;
  final int amount;
  final double percentage;
  final int transactionCount;

  const CategoryStatistics({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
  });

  @override
  List<Object?> get props => [category, amount, percentage, transactionCount];
}
