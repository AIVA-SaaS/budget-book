import 'package:equatable/equatable.dart';

sealed class WeeklySettlementEvent extends Equatable {
  const WeeklySettlementEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettlements extends WeeklySettlementEvent {
  final int year;
  final int month;

  const LoadSettlements({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class SettleItems extends WeeklySettlementEvent {
  final List<String> budgetIds;
  final int weekNumber;
  final int year;
  final int month;

  const SettleItems({
    required this.budgetIds,
    required this.weekNumber,
    required this.year,
    required this.month,
  });

  @override
  List<Object?> get props => [budgetIds, weekNumber, year, month];
}

class UnsettleItems extends WeeklySettlementEvent {
  final List<String> budgetIds;
  final int weekNumber;
  final int year;
  final int month;

  const UnsettleItems({
    required this.budgetIds,
    required this.weekNumber,
    required this.year,
    required this.month,
  });

  @override
  List<Object?> get props => [budgetIds, weekNumber, year, month];
}
