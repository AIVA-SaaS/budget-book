import 'package:budget_book/features/weekly_budget/domain/entities/weekly_overview.dart';

class WeekSummaryModel extends WeekSummary {
  const WeekSummaryModel({
    required super.weekNumber,
    required super.weekStart,
    required super.weekEnd,
    required super.budgetAmount,
    required super.spentAmount,
    required super.remainingAmount,
    required super.usageRate,
    required super.status,
  });

  factory WeekSummaryModel.fromJson(Map<String, dynamic> json) {
    return WeekSummaryModel(
      weekNumber: json['weekNumber'] as int,
      weekStart: json['weekStart'] as String,
      weekEnd: json['weekEnd'] as String,
      budgetAmount: json['budgetAmount'] as int,
      spentAmount: json['spentAmount'] as int,
      remainingAmount: json['remainingAmount'] as int,
      usageRate: (json['usageRate'] as num).toDouble(),
      status: json['status'] as String,
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
          .map((e) => WeekSummaryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
