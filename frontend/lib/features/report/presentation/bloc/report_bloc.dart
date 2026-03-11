import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/report/domain/repositories/report_repository.dart';
import 'report_event.dart';
import 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ReportRepository reportRepository;

  ReportBloc({required this.reportRepository}) : super(const ReportInitial()) {
    on<LoadWeeklyReport>(_onLoadWeeklyReport);
    on<LoadMonthlyReport>(_onLoadMonthlyReport);
  }

  Future<void> _onLoadWeeklyReport(
    LoadWeeklyReport event,
    Emitter<ReportState> emit,
  ) async {
    final currentMonthly = state is ReportLoaded
        ? (state as ReportLoaded).monthlyReport
        : null;

    emit(const ReportLoading());
    final result = await reportRepository.getWeeklyReport(
      event.year,
      event.month,
      event.week,
    );
    result.fold(
      (failure) => emit(ReportError(failure.message)),
      (report) =>
          emit(ReportLoaded(weeklyReport: report, monthlyReport: currentMonthly)),
    );
  }

  Future<void> _onLoadMonthlyReport(
    LoadMonthlyReport event,
    Emitter<ReportState> emit,
  ) async {
    final currentWeekly = state is ReportLoaded
        ? (state as ReportLoaded).weeklyReport
        : null;

    emit(const ReportLoading());
    final result = await reportRepository.getMonthlyReport(
      event.year,
      event.month,
    );
    result.fold(
      (failure) => emit(ReportError(failure.message)),
      (report) =>
          emit(ReportLoaded(weeklyReport: currentWeekly, monthlyReport: report)),
    );
  }
}
