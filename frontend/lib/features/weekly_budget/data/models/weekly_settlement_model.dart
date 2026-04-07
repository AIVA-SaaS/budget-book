import 'package:budget_book/features/weekly_budget/domain/entities/weekly_settlement.dart';

class WeeklySettlementItemModel extends WeeklySettlementItem {
  const WeeklySettlementItemModel({
    required super.budgetId,
    super.categoryId,
    super.categoryName,
    super.categoryIcon,
    super.categoryColor,
    super.groupId,
    super.groupName,
    required super.spentAmount,
    required super.status,
    super.settledAt,
  });

  factory WeeklySettlementItemModel.fromJson(Map<String, dynamic> json) {
    return WeeklySettlementItemModel(
      budgetId: json['budgetId'] as String,
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
      categoryIcon: json['categoryIcon'] as String?,
      categoryColor: json['categoryColor'] as String?,
      groupId: json['groupId'] as String?,
      groupName: json['groupName'] as String?,
      spentAmount: json['spentAmount'] as int,
      status: (json['status'] as String) == 'SETTLED'
          ? SettlementStatus.settled
          : SettlementStatus.pending,
      settledAt: json['settledAt'] as String?,
    );
  }
}

class WeeklySettlementWeekModel extends WeeklySettlementWeek {
  const WeeklySettlementWeekModel({
    required super.weekNumber,
    required super.weekStart,
    required super.weekEnd,
    required super.totalSpent,
    required super.settledCount,
    required super.totalCount,
    required super.items,
  });

  factory WeeklySettlementWeekModel.fromJson(Map<String, dynamic> json) {
    return WeeklySettlementWeekModel(
      weekNumber: json['weekNumber'] as int,
      weekStart: json['weekStart'] as String,
      weekEnd: json['weekEnd'] as String,
      totalSpent: json['totalSpent'] as int,
      settledCount: json['settledCount'] as int,
      totalCount: json['totalCount'] as int,
      items: (json['items'] as List<dynamic>)
          .map((e) =>
              WeeklySettlementItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WeeklySettlementOverviewModel extends WeeklySettlementOverview {
  const WeeklySettlementOverviewModel({
    required super.yearMonth,
    required super.weeks,
  });

  factory WeeklySettlementOverviewModel.fromJson(Map<String, dynamic> json) {
    return WeeklySettlementOverviewModel(
      yearMonth: json['yearMonth'] as String,
      weeks: (json['weeks'] as List<dynamic>)
          .map((e) =>
              WeeklySettlementWeekModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
