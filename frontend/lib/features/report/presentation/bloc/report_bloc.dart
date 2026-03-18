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
    try {
      final currentMonthly = state is ReportLoaded
          ? (state as ReportLoaded).monthlyReport
          : null;

      // Only emit ReportLoading if we have no partial data yet;
      // otherwise preserve existing data to avoid a UI flash.
      if (state is! ReportLoaded) {
        emit(const ReportLoading());
      }
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
    } catch (e) {
      emit(const ReportError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onLoadMonthlyReport(
    LoadMonthlyReport event,
    Emitter<ReportState> emit,
  ) async {
    try {
      final currentWeekly = state is ReportLoaded
          ? (state as ReportLoaded).weeklyReport
          : null;

      // Only emit ReportLoading if we have no partial data yet;
      // otherwise preserve existing data to avoid a UI flash.
      if (state is! ReportLoaded) {
        emit(const ReportLoading());
      }
      final result = await reportRepository.getMonthlyReport(
        event.year,
        event.month,
      );
      result.fold(
        (failure) => emit(ReportError(failure.message)),
        (report) =>
            emit(ReportLoaded(weeklyReport: currentWeekly, monthlyReport: report)),
      );
    } catch (e) {
      emit(const ReportError('예기치 않은 오류가 발생했습니다'));
    }
  }
}
