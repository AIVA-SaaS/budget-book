import 'package:equatable/equatable.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_overview.dart';

class CurrentWeekSummary extends Equatable {
  final String yearMonth;
  final int weekNumber;
  final String weekStart;
  final String weekEnd;
  final List<WeeklyBudgetItem> items;

  const CurrentWeekSummary({
    required this.yearMonth,
    required this.weekNumber,
    required this.weekStart,
    required this.weekEnd,
    required this.items,
  });

  int get totalBudget =>
      items.fold(0, (sum, item) => sum + item.budgetAmount);

  int get totalSpent =>
      items.fold(0, (sum, item) => sum + item.spentAmount);

  int get totalRemaining =>
      items.fold(0, (sum, item) => sum + item.remainingAmount);

  @override
  List<Object?> get props => [yearMonth, weekNumber, weekStart, weekEnd, items];
}
