import 'package:equatable/equatable.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_settlement.dart';

sealed class WeeklySettlementState extends Equatable {
  const WeeklySettlementState();

  @override
  List<Object?> get props => [];
}

class SettlementInitial extends WeeklySettlementState {
  const SettlementInitial();
}

class SettlementLoading extends WeeklySettlementState {
  const SettlementLoading();
}

class SettlementLoaded extends WeeklySettlementState {
  final WeeklySettlementOverview overview;

  const SettlementLoaded({required this.overview});

  @override
  List<Object?> get props => [overview];
}

class SettlementError extends WeeklySettlementState {
  final String message;

  const SettlementError(this.message);

  @override
  List<Object?> get props => [message];
}
