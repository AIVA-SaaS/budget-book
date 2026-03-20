import 'package:budget_book/features/weekly_budget/domain/entities/weekly_overview.dart';

class WeeklyBudgetItemModel extends WeeklyBudgetItem {
  const WeeklyBudgetItemModel({
    required super.budgetId,
    super.categoryId,
    super.categoryName,
    super.groupId,
    super.groupName,
    required super.budgetAmount,
    required super.spentAmount,
    required super.remainingAmount,
    required super.usageRate,
  });

  factory WeeklyBudgetItemModel.fromJson(Map<String, dynamic> json) {
    return WeeklyBudgetItemModel(
      budgetId: json['budgetId'] as String,
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
      groupId: json['groupId'] as String?,
      groupName: json['groupName'] as String?,
      budgetAmount: json['budgetAmount'] as int,
      spentAmount: json['spentAmount'] as int,
      remainingAmount: json['remainingAmount'] as int,
      usageRate: (json['usageRate'] as num).toDouble(),
    );
  }
}

class WeeklyWeekModel extends WeeklyWeek {
  const WeeklyWeekModel({
    required super.weekNumber,
    required super.weekStart,
    required super.weekEnd,
    required super.totalBudget,
    required super.totalSpent,
    required super.totalRemaining,
    required super.items,
  });

  factory WeeklyWeekModel.fromJson(Map<String, dynamic> json) {
    return WeeklyWeekModel(
      weekNumber: json['weekNumber'] as int,
      weekStart: json['weekStart'] as String,
      weekEnd: json['weekEnd'] as String,
      totalBudget: json['totalBudget'] as int,
      totalSpent: json['totalSpent'] as int,
      totalRemaining: json['totalRemaining'] as int,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) =>
                  WeeklyBudgetItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class WeeklyOverviewModel extends WeeklyOverview {
  const WeeklyOverviewModel({
    required super.yearMonth,
    required super.weeks,
  });

  factory WeeklyOverviewModel.fromJson(Map<String, dynamic> json) {
    return WeeklyOverviewModel(
      yearMonth: json['yearMonth'] as String,
      weeks: (json['weeks'] as List<dynamic>)
          .map((e) => WeeklyWeekModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
