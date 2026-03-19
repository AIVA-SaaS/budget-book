import 'package:equatable/equatable.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';

class Budget extends Equatable {
  final String id;
  final String coupleId;
  final TransactionCategory? category;
  final String? groupId;
  final String? groupName;
  final String yearMonth;
  final int amount;
  final String budgetPeriod;
  final int? weeklyAmount;
  final String? pocketId;
  final String? pocketName;
  final String periodType;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    required this.coupleId,
    this.category,
    this.groupId,
    this.groupName,
    required this.yearMonth,
    required this.amount,
    this.budgetPeriod = 'MONTHLY',
    this.weeklyAmount,
    this.pocketId,
    this.pocketName,
    this.periodType = 'MONTHLY',
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display label for this budget target (category, group, or total).
  String get targetLabel {
    if (category != null) return category!.name;
    if (groupName != null) return '$groupName (그룹)';
    return '전체 예산';
  }

  @override
  List<Object?> get props => [
        id,
        coupleId,
        category,
        groupId,
        groupName,
        yearMonth,
        amount,
        budgetPeriod,
        weeklyAmount,
        pocketId,
        pocketName,
        periodType,
        startDate,
        endDate,
        createdAt,
        updatedAt,
      ];
}

class BudgetSummary extends Equatable {
  final String yearMonth;
  final int totalBudget;
  final int totalSpent;
  final List<BudgetSummaryItem> items;

  const BudgetSummary({
    required this.yearMonth,
    required this.totalBudget,
    required this.totalSpent,
    required this.items,
  });

  int get remainingAmount => totalBudget - totalSpent;

  double get usageRate =>
      totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0;

  bool get isOverBudget => totalSpent > totalBudget;

  @override
  List<Object?> get props => [yearMonth, totalBudget, totalSpent, items];
}

class BudgetSummaryItem extends Equatable {
  final TransactionCategory? category;
  final int budgetAmount;
  final int spentAmount;
  final int remainingAmount;
  final double usageRate;

  const BudgetSummaryItem({
    this.category,
    required this.budgetAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.usageRate,
  });

  bool get isOverBudget => spentAmount > budgetAmount;

  @override
  List<Object?> get props =>
      [category, budgetAmount, spentAmount, remainingAmount, usageRate];
}
