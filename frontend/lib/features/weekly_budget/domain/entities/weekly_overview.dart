import 'package:equatable/equatable.dart';

class WeekSummary extends Equatable {
  final int weekNumber;
  final String weekStart;
  final String weekEnd;
  final int budgetAmount;
  final int spentAmount;
  final int remainingAmount;
  final double usageRate;
  final String status;

  const WeekSummary({
    required this.weekNumber,
    required this.weekStart,
    required this.weekEnd,
    required this.budgetAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.usageRate,
    required this.status,
  });

  bool get isOver => status == 'OVER';
  bool get isUnder => status == 'UNDER';
  bool get isInProgress => status == 'IN_PROGRESS';

  @override
  List<Object?> get props => [
        weekNumber,
        weekStart,
        weekEnd,
        budgetAmount,
        spentAmount,
        remainingAmount,
        usageRate,
        status,
      ];
}

class WeeklyOverview extends Equatable {
  final String yearMonth;
  final List<WeekSummary> weeks;

  const WeeklyOverview({
    required this.yearMonth,
    required this.weeks,
  });

  @override
  List<Object?> get props => [yearMonth, weeks];
}
