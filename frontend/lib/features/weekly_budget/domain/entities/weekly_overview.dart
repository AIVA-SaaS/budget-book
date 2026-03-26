import 'package:equatable/equatable.dart';

class WeeklyBudgetItem extends Equatable {
  final String budgetId;
  final String? categoryId;
  final String? categoryName;
  final String? groupId;
  final String? groupName;
  final int budgetAmount;
  final int spentAmount;
  final int remainingAmount;
  final double usageRate;

  const WeeklyBudgetItem({
    required this.budgetId,
    this.categoryId,
    this.categoryName,
    this.groupId,
    this.groupName,
    required this.budgetAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.usageRate,
  });

  /// Display label: prefer categoryName, then groupName, fallback to empty
  String get displayName =>
      categoryName ?? groupName ?? '';

  @override
  List<Object?> get props => [
        budgetId,
        categoryId,
        categoryName,
        groupId,
        groupName,
        budgetAmount,
        spentAmount,
        remainingAmount,
        usageRate,
      ];
}

class WeeklyWeek extends Equatable {
  final int weekNumber;
  final String weekStart;
  final String weekEnd;
  final int totalBudget;
  final int totalSpent;
  final int totalRemaining;
  final List<WeeklyBudgetItem> items;

  const WeeklyWeek({
    required this.weekNumber,
    required this.weekStart,
    required this.weekEnd,
    required this.totalBudget,
    required this.totalSpent,
    required this.totalRemaining,
    required this.items,
  });

  double get totalUsageRate =>
      totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0.0;

  @override
  List<Object?> get props => [
        weekNumber,
        weekStart,
        weekEnd,
        totalBudget,
        totalSpent,
        totalRemaining,
        items,
      ];
}

class WeeklyOverview extends Equatable {
  final String yearMonth;
  final List<WeeklyWeek> weeks;

  const WeeklyOverview({
    required this.yearMonth,
    required this.weeks,
  });

  @override
  List<Object?> get props => [yearMonth, weeks];
}
