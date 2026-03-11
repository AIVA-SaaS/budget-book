import 'package:budget_book/features/weekly_budget/domain/entities/current_week_summary.dart';

class WeeklyGroupSummaryModel extends WeeklyGroupSummary {
  const WeeklyGroupSummaryModel({
    required super.groupId,
    required super.groupName,
    required super.budgetAmount,
    required super.spentAmount,
    required super.remainingAmount,
    required super.usageRate,
  });

  factory WeeklyGroupSummaryModel.fromJson(Map<String, dynamic> json) {
    return WeeklyGroupSummaryModel(
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      budgetAmount: json['budgetAmount'] as int,
      spentAmount: json['spentAmount'] as int,
      remainingAmount: json['remainingAmount'] as int,
      usageRate: (json['usageRate'] as num).toDouble(),
    );
  }
}

class CurrentWeekSummaryModel extends CurrentWeekSummary {
  const CurrentWeekSummaryModel({
    required super.yearMonth,
    required super.weekNumber,
    required super.weekStart,
    required super.weekEnd,
    required super.groups,
  });

  factory CurrentWeekSummaryModel.fromJson(Map<String, dynamic> json) {
    return CurrentWeekSummaryModel(
      yearMonth: json['yearMonth'] as String,
      weekNumber: json['weekNumber'] as int,
      weekStart: json['weekStart'] as String,
      weekEnd: json['weekEnd'] as String,
      groups: (json['groups'] as List<dynamic>)
          .map((e) =>
              WeeklyGroupSummaryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
