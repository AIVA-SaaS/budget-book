import 'package:equatable/equatable.dart';

sealed class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

class LoadWeeklyReport extends ReportEvent {
  final int year;
  final int month;
  final int week;

  const LoadWeeklyReport({
    required this.year,
    required this.month,
    required this.week,
  });

  @override
  List<Object?> get props => [year, month, week];
}

class LoadMonthlyReport extends ReportEvent {
  final int year;
  final int month;

  const LoadMonthlyReport({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}
