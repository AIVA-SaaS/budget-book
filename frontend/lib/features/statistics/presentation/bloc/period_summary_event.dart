import 'package:equatable/equatable.dart';

sealed class PeriodSummaryEvent extends Equatable {
  const PeriodSummaryEvent();

  @override
  List<Object?> get props => [];
}

class LoadPeriodSummary extends PeriodSummaryEvent {
  final String dateFrom;
  final String dateTo;
  final String? categoryId;
  final String? paymentMethodId;
  final String? pocketId;

  const LoadPeriodSummary({
    required this.dateFrom,
    required this.dateTo,
    this.categoryId,
    this.paymentMethodId,
    this.pocketId,
  });

  @override
  List<Object?> get props => [dateFrom, dateTo, categoryId, paymentMethodId, pocketId];
}
