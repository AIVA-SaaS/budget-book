import 'package:equatable/equatable.dart';
import 'package:budget_book/features/statistics/domain/entities/period_summary.dart';

sealed class PeriodSummaryState extends Equatable {
  const PeriodSummaryState();

  @override
  List<Object?> get props => [];
}

class PeriodSummaryInitial extends PeriodSummaryState {
  const PeriodSummaryInitial();
}

class PeriodSummaryLoading extends PeriodSummaryState {
  const PeriodSummaryLoading();
}

class PeriodSummaryLoaded extends PeriodSummaryState {
  final PeriodSummary summary;

  const PeriodSummaryLoaded(this.summary);

  @override
  List<Object?> get props => [summary];
}

class PeriodSummaryError extends PeriodSummaryState {
  final String message;

  const PeriodSummaryError(this.message);

  @override
  List<Object?> get props => [message];
}
