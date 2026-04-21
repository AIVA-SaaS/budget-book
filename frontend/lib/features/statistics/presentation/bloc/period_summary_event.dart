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
  final Set<String> categoryIds;
  final Set<String> categoryGroupIds;
  final String? paymentMethodId;
  final Set<String> paymentMethodIds;
  final String? pocketId;
  final Set<String> pocketIds;

  const LoadPeriodSummary({
    required this.dateFrom,
    required this.dateTo,
    this.categoryId,
    this.categoryIds = const {},
    this.categoryGroupIds = const {},
    this.paymentMethodId,
    this.paymentMethodIds = const {},
    this.pocketId,
    this.pocketIds = const {},
  });

  @override
  List<Object?> get props => [
        dateFrom,
        dateTo,
        categoryId,
        categoryIds,
        categoryGroupIds,
        paymentMethodId,
        paymentMethodIds,
        pocketId,
        pocketIds,
      ];
}
