import 'package:equatable/equatable.dart';

class WeeklyGroupSummary extends Equatable {
  final String groupId;
  final String groupName;
  final int budgetAmount;
  final int spentAmount;
  final int remainingAmount;
  final double usageRate;

  const WeeklyGroupSummary({
    required this.groupId,
    required this.groupName,
    required this.budgetAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.usageRate,
  });

  @override
  List<Object?> get props => [
        groupId,
        groupName,
        budgetAmount,
        spentAmount,
        remainingAmount,
        usageRate,
      ];
}

class CurrentWeekSummary extends Equatable {
  final String yearMonth;
  final int weekNumber;
  final String weekStart;
  final String weekEnd;
  final List<WeeklyGroupSummary> groups;

  const CurrentWeekSummary({
    required this.yearMonth,
    required this.weekNumber,
    required this.weekStart,
    required this.weekEnd,
    required this.groups,
  });

  @override
  List<Object?> get props => [yearMonth, weekNumber, weekStart, weekEnd, groups];
}
