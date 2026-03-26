import 'package:budget_book/features/weekly_budget/domain/entities/current_week_summary.dart';
import 'package:budget_book/features/weekly_budget/data/models/weekly_overview_model.dart';

class CurrentWeekSummaryModel extends CurrentWeekSummary {
  const CurrentWeekSummaryModel({
    required super.yearMonth,
    required super.weekNumber,
    required super.weekStart,
    required super.weekEnd,
    required super.items,
  });

  factory CurrentWeekSummaryModel.fromJson(Map<String, dynamic> json) {
    return CurrentWeekSummaryModel(
      yearMonth: json['yearMonth'] as String,
      weekNumber: json['weekNumber'] as int,
      weekStart: json['weekStart'] as String,
      weekEnd: json['weekEnd'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) =>
                  WeeklyBudgetItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
