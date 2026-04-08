import 'package:equatable/equatable.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_overview.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/current_week_summary.dart';

sealed class WeeklyBudgetState extends Equatable {
  const WeeklyBudgetState();

  @override
  List<Object?> get props => [];
}

class WeeklyBudgetInitial extends WeeklyBudgetState {
  const WeeklyBudgetInitial();
}

class WeeklyBudgetLoading extends WeeklyBudgetState {
  const WeeklyBudgetLoading();
}

class WeeklyBudgetLoaded extends WeeklyBudgetState {
  final WeeklyOverview? overview;
  final CurrentWeekSummary? currentWeek;
  final int year;
  final int month;

  WeeklyBudgetLoaded({
    this.overview,
    this.currentWeek,
    int? year,
    int? month,
  })  : year = year ?? DateTime.now().year,
        month = month ?? DateTime.now().month;

  @override
  List<Object?> get props => [overview, currentWeek, year, month];
}

class WeeklyBudgetError extends WeeklyBudgetState {
  final String message;

  const WeeklyBudgetError(this.message);

  @override
  List<Object?> get props => [message];
}
