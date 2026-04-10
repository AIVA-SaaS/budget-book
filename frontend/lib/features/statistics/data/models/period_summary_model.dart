import 'package:budget_book/features/statistics/domain/entities/period_summary.dart';

class PeriodSummaryModel extends PeriodSummary {
  const PeriodSummaryModel({
    required super.dateFrom,
    required super.dateTo,
    required super.totalIncome,
    required super.totalExpense,
    required super.balance,
    super.byCategory = const [],
    super.byBudget = const [],
    super.byPaymentMethod = const [],
    super.byDate = const [],
  });

  factory PeriodSummaryModel.fromJson(Map<String, dynamic> json) {
    return PeriodSummaryModel(
      dateFrom: json['dateFrom'] as String,
      dateTo: json['dateTo'] as String,
      totalIncome: json['totalIncome'] as int,
      totalExpense: json['totalExpense'] as int,
      balance: json['balance'] as int,
      byCategory: (json['byCategory'] as List<dynamic>?)
              ?.map((e) => PeriodCategoryItemModel.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          const [],
      byBudget: (json['byBudget'] as List<dynamic>?)
              ?.map((e) => PeriodBudgetItemModel.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          const [],
      byPaymentMethod: (json['byPaymentMethod'] as List<dynamic>?)
              ?.map((e) => PeriodPaymentMethodItemModel.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          const [],
      byDate: (json['byDate'] as List<dynamic>?)
              ?.map((e) =>
                  PeriodDateItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class PeriodCategoryItemModel extends PeriodCategoryItem {
  const PeriodCategoryItemModel({
    required super.categoryName,
    required super.amount,
    required super.count,
    required super.percentage,
  });

  factory PeriodCategoryItemModel.fromJson(Map<String, dynamic> json) {
    return PeriodCategoryItemModel(
      categoryName: json['categoryName'] as String,
      amount: json['amount'] as int,
      count: json['count'] as int,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class PeriodBudgetItemModel extends PeriodBudgetItem {
  const PeriodBudgetItemModel({
    required super.budgetName,
    required super.budgetAmount,
    required super.spent,
    required super.remaining,
  });

  factory PeriodBudgetItemModel.fromJson(Map<String, dynamic> json) {
    return PeriodBudgetItemModel(
      budgetName: json['budgetName'] as String,
      budgetAmount: json['budgetAmount'] as int,
      spent: json['spent'] as int,
      remaining: json['remaining'] as int,
    );
  }
}

class PeriodPaymentMethodItemModel extends PeriodPaymentMethodItem {
  const PeriodPaymentMethodItemModel({
    required super.methodName,
    required super.amount,
    required super.count,
  });

  factory PeriodPaymentMethodItemModel.fromJson(Map<String, dynamic> json) {
    return PeriodPaymentMethodItemModel(
      methodName: json['methodName'] as String,
      amount: json['amount'] as int,
      count: json['count'] as int,
    );
  }
}

class PeriodDateItemModel extends PeriodDateItem {
  const PeriodDateItemModel({
    required super.date,
    required super.income,
    required super.expense,
  });

  factory PeriodDateItemModel.fromJson(Map<String, dynamic> json) {
    return PeriodDateItemModel(
      date: json['date'] as String,
      income: json['income'] as int,
      expense: json['expense'] as int,
    );
  }
}
