import 'package:equatable/equatable.dart';

sealed class WeeklyBudgetEvent extends Equatable {
  const WeeklyBudgetEvent();

  @override
  List<Object?> get props => [];
}

class LoadWeeklyOverview extends WeeklyBudgetEvent {
  final int year;
  final int month;

  const LoadWeeklyOverview({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class LoadCurrentWeek extends WeeklyBudgetEvent {
  const LoadCurrentWeek();
}
