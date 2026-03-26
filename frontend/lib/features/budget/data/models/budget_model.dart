import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/transaction/data/models/transaction_category_model.dart';

class BudgetModel extends Budget {
  const BudgetModel({
    required super.id,
    required super.coupleId,
    super.category,
    super.groupId,
    super.groupName,
    required super.yearMonth,
    required super.amount,
    super.budgetPeriod,
    super.weeklyAmount,
    super.pocketId,
    super.pocketName,
    super.periodType,
    super.startDate,
    super.endDate,
    super.visibility,
    super.ownerId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as String,
      coupleId: json['coupleId'] as String,
      category: json['category'] != null
          ? TransactionCategoryModel.fromJson(
              json['category'] as Map<String, dynamic>)
          : null,
      groupId: json['groupId'] as String?,
      groupName: json['groupName'] as String?,
      yearMonth: json['yearMonth'] as String,
      amount: json['amount'] as int,
      budgetPeriod: json['budgetPeriod'] as String? ?? 'MONTHLY',
      weeklyAmount: json['weeklyAmount'] as int?,
      pocketId: json['pocketId'] as String?,
      pocketName: json['pocketName'] as String?,
      periodType: json['periodType'] as String? ?? 'MONTHLY',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      visibility: json['visibility'] as String? ?? 'SHARED',
      ownerId: json['ownerId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class BudgetSummaryModel extends BudgetSummary {
  const BudgetSummaryModel({
    required super.yearMonth,
    required super.totalBudget,
    required super.totalSpent,
    required super.items,
  });

  factory BudgetSummaryModel.fromJson(Map<String, dynamic> json) {
    return BudgetSummaryModel(
      yearMonth: json['yearMonth'] as String,
      totalBudget: json['totalBudget'] as int,
      totalSpent: json['totalSpent'] as int,
      items: (json['items'] as List<dynamic>)
          .map((e) =>
              BudgetSummaryItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BudgetSummaryItemModel extends BudgetSummaryItem {
  const BudgetSummaryItemModel({
    super.category,
    super.groupId,
    super.groupName,
    required super.budgetAmount,
    required super.spentAmount,
    required super.remainingAmount,
    required super.usageRate,
  });

  factory BudgetSummaryItemModel.fromJson(Map<String, dynamic> json) {
    return BudgetSummaryItemModel(
      category: json['category'] != null
          ? TransactionCategoryModel.fromJson(
              json['category'] as Map<String, dynamic>)
          : null,
      groupId: json['groupId'] as String?,
      groupName: json['groupName'] as String?,
      budgetAmount: json['budgetAmount'] as int,
      spentAmount: json['spentAmount'] as int,
      remainingAmount: json['remainingAmount'] as int,
      usageRate: (json['usageRate'] as num).toDouble(),
    );
  }
}
