import 'package:equatable/equatable.dart';

enum SettlementStatus { pending, settled }

class WeeklySettlementItem extends Equatable {
  final String budgetId;
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final String? groupId;
  final String? groupName;
  final int spentAmount;
  final SettlementStatus status;
  final String? settledAt;

  const WeeklySettlementItem({
    required this.budgetId,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.groupId,
    this.groupName,
    required this.spentAmount,
    required this.status,
    this.settledAt,
  });

  String get displayName => categoryName ?? groupName ?? '';

  bool get isSettled => status == SettlementStatus.settled;

  @override
  List<Object?> get props => [
        budgetId,
        categoryId,
        categoryName,
        categoryIcon,
        categoryColor,
        groupId,
        groupName,
        spentAmount,
        status,
        settledAt,
      ];
}

class WeeklySettlementWeek extends Equatable {
  final int weekNumber;
  final String weekStart;
  final String weekEnd;
  final int totalSpent;
  final int settledCount;
  final int totalCount;
  final List<WeeklySettlementItem> items;

  const WeeklySettlementWeek({
    required this.weekNumber,
    required this.weekStart,
    required this.weekEnd,
    required this.totalSpent,
    required this.settledCount,
    required this.totalCount,
    required this.items,
  });

  bool get isFullySettled => totalCount > 0 && settledCount == totalCount;

  @override
  List<Object?> get props => [
        weekNumber,
        weekStart,
        weekEnd,
        totalSpent,
        settledCount,
        totalCount,
        items,
      ];
}

class WeeklySettlementOverview extends Equatable {
  final String yearMonth;
  final List<WeeklySettlementWeek> weeks;

  const WeeklySettlementOverview({
    required this.yearMonth,
    required this.weeks,
  });

  @override
  List<Object?> get props => [yearMonth, weeks];
}
