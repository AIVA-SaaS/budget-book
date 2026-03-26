import 'package:budget_book/features/report/domain/entities/weekly_report.dart';

class OverspendCategoryModel extends OverspendCategory {
  const OverspendCategoryModel({
    required super.categoryId,
    required super.categoryName,
    required super.categoryType,
    super.categoryIcon,
    super.categoryColor,
    required super.amount,
    required super.averageAmount,
    required super.deviation,
    required super.transactionCount,
  });

  factory OverspendCategoryModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>;
    final name = category['name'] as String;
    final groupName = category['groupName'] as String?;
    final displayName =
        groupName != null && groupName.isNotEmpty ? '$groupName > $name' : name;
    return OverspendCategoryModel(
      categoryId: category['id'] as String,
      categoryName: displayName,
      categoryType: category['type'] as String,
      categoryIcon: category['icon'] as String?,
      categoryColor: category['color'] as String?,
      amount: json['amount'] as int,
      averageAmount: json['averageAmount'] as int,
      deviation: json['deviation'] as int,
      transactionCount: json['transactionCount'] as int,
    );
  }
}

class DailySpendingModel extends DailySpending {
  const DailySpendingModel({
    required super.date,
    required super.dayOfWeek,
    required super.amount,
    required super.transactionCount,
  });

  factory DailySpendingModel.fromJson(Map<String, dynamic> json) {
    return DailySpendingModel(
      date: json['date'] as String,
      dayOfWeek: json['dayOfWeek'] as String,
      amount: json['amount'] as int,
      transactionCount: json['transactionCount'] as int,
    );
  }
}

class WeeklyReportModel extends WeeklyReport {
  const WeeklyReportModel({
    required super.yearMonth,
    required super.weekNumber,
    required super.weekStart,
    required super.weekEnd,
    required super.totalBudget,
    required super.totalSpent,
    required super.remainingAmount,
    required super.usageRate,
    required super.status,
    required super.topOverspendCategories,
    required super.dailySpending,
    required super.peakSpendingDay,
  });

  factory WeeklyReportModel.fromJson(Map<String, dynamic> json) {
    return WeeklyReportModel(
      yearMonth: json['yearMonth'] as String,
      weekNumber: json['weekNumber'] as int,
      weekStart: json['weekStart'] as String,
      weekEnd: json['weekEnd'] as String,
      totalBudget: json['totalBudget'] as int,
      totalSpent: json['totalSpent'] as int,
      remainingAmount: json['remainingAmount'] as int,
      usageRate: (json['usageRate'] as num).toDouble(),
      status: json['status'] as String,
      topOverspendCategories: (json['topOverspendCategories'] as List<dynamic>)
          .map((e) =>
              OverspendCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailySpending: (json['dailySpending'] as List<dynamic>)
          .map((e) => DailySpendingModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      peakSpendingDay: json['peakSpendingDay'] as String,
    );
  }
}
