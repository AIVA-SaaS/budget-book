import 'package:equatable/equatable.dart';
import 'package:budget_book/features/report/domain/entities/weekly_report.dart';
import 'package:budget_book/features/report/domain/entities/monthly_report.dart';

sealed class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {
  const ReportInitial();
}

class ReportLoading extends ReportState {
  const ReportLoading();
}

class ReportLoaded extends ReportState {
  final WeeklyReport? weeklyReport;
  final MonthlyReport? monthlyReport;

  const ReportLoaded({this.weeklyReport, this.monthlyReport});

  @override
  List<Object?> get props => [weeklyReport, monthlyReport];
}

class ReportError extends ReportState {
  final String message;

  const ReportError(this.message);

  @override
  List<Object?> get props => [message];
}
