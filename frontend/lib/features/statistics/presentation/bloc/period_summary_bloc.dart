import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';
import 'period_summary_event.dart';
import 'period_summary_state.dart';

class PeriodSummaryBloc extends Bloc<PeriodSummaryEvent, PeriodSummaryState> {
  final StatisticsRepository statisticsRepository;

  PeriodSummaryBloc({required this.statisticsRepository})
      : super(const PeriodSummaryInitial()) {
    on<LoadPeriodSummary>(_onLoadPeriodSummary);
  }

  Future<void> _onLoadPeriodSummary(
    LoadPeriodSummary event,
    Emitter<PeriodSummaryState> emit,
  ) async {
    emit(const PeriodSummaryLoading());

    try {
      final result = await statisticsRepository.getPeriodSummary(
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
      );
      result.fold(
        (failure) => emit(PeriodSummaryError(failure.message)),
        (summary) => emit(PeriodSummaryLoaded(summary)),
      );
    } catch (e) {
      emit(const PeriodSummaryError('기간별 통계를 불러오지 못했습니다'));
    }
  }
}
