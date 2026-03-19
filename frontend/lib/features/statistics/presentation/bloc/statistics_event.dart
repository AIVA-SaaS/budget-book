import 'package:equatable/equatable.dart';

sealed class StatisticsEvent extends Equatable {
  const StatisticsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSummary extends StatisticsEvent {
  final int year;
  final int month;

  const LoadSummary({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class LoadCategoryBreakdown extends StatisticsEvent {
  final int year;
  final int month;
  final String type;

  const LoadCategoryBreakdown({
    required this.year,
    required this.month,
    this.type = 'EXPENSE',
  });

  @override
  List<Object?> get props => [year, month, type];
}

class LoadMonthlyTrend extends StatisticsEvent {
  final int months;

  const LoadMonthlyTrend({this.months = 6});

  @override
  List<Object?> get props => [months];
}

class LoadAllStatistics extends StatisticsEvent {
  final int year;
  final int month;

  const LoadAllStatistics({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class LoadYearComparison extends StatisticsEvent {
  final int year;
  final int month;

  const LoadYearComparison({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class LoadPaymentMethodStats extends StatisticsEvent {
  final int year;
  final int month;

  const LoadPaymentMethodStats({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class ChangeVisibilityFilter extends StatisticsEvent {
  final String visibility; // 'ALL', 'SHARED', 'PRIVATE'

  const ChangeVisibilityFilter(this.visibility);

  @override
  List<Object?> get props => [visibility];
}
