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

  const WeeklyBudgetLoaded({this.overview, this.currentWeek});

  @override
  List<Object?> get props => [overview, currentWeek];
}

class WeeklyBudgetError extends WeeklyBudgetState {
  final String message;

  const WeeklyBudgetError(this.message);

  @override
  List<Object?> get props => [message];
}
