import 'package:equatable/equatable.dart';

sealed class PeriodSummaryEvent extends Equatable {
  const PeriodSummaryEvent();

  @override
  List<Object?> get props => [];
}

class LoadPeriodSummary extends PeriodSummaryEvent {
  final String dateFrom;
  final String dateTo;

  const LoadPeriodSummary({required this.dateFrom, required this.dateTo});

  @override
  List<Object?> get props => [dateFrom, dateTo];
}
