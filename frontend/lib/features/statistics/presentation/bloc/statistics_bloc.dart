import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';
import 'statistics_event.dart';
import 'statistics_state.dart';

class StatisticsBloc extends Bloc<StatisticsEvent, StatisticsState> {
  final StatisticsRepository statisticsRepository;

  StatisticsBloc({required this.statisticsRepository})
      : super(StatisticsState(
          year: DateTime.now().year,
          month: DateTime.now().month,
        )) {
    on<LoadAllStatistics>(_onLoadAll);
    on<LoadSummary>(_onLoadSummary);
    on<LoadCategoryBreakdown>(_onLoadCategoryBreakdown);
    on<LoadMonthlyTrend>(_onLoadMonthlyTrend);
  }

  Future<void> _onLoadAll(
    LoadAllStatistics event,
    Emitter<StatisticsState> emit,
  ) async {
    emit(state.copyWith(
      year: event.year,
      month: event.month,
      summaryLoading: true,
      categoryLoading: true,
      trendLoading: true,
      clearSummaryError: true,
      clearCategoryError: true,
      clearTrendError: true,
    ));

    // Load all three API calls in parallel using Future.wait
    final results = await Future.wait([
      statisticsRepository.getSummary(
        year: event.year,
        month: event.month,
      ),
      statisticsRepository.getCategoryBreakdown(
        year: event.year,
        month: event.month,
        type: state.categoryType,
      ),
      statisticsRepository.getMonthlyTrend(),
    ]);

    // Process summary result
    results[0].fold(
      (failure) => emit(state.copyWith(
        summaryLoading: false,
        summaryError: failure.message,
      )),
      (data) => emit(state.copyWith(
        summaryLoading: false,
        summary: data as StatisticsSummary,
      )),
    );

    // Process category breakdown result
    results[1].fold(
      (failure) => emit(state.copyWith(
        categoryLoading: false,
        categoryError: failure.message,
      )),
      (data) => emit(state.copyWith(
        categoryLoading: false,
        categoryStats: data as List<CategoryStatistics>,
      )),
    );

    // Process monthly trend result
    results[2].fold(
      (failure) => emit(state.copyWith(
        trendLoading: false,
        trendError: failure.message,
      )),
      (data) => emit(state.copyWith(
        trendLoading: false,
        trends: data as List<MonthlyTrend>,
      )),
    );
  }

  Future<void> _onLoadSummary(
    LoadSummary event,
    Emitter<StatisticsState> emit,
  ) async {
    emit(state.copyWith(
      year: event.year,
      month: event.month,
      summaryLoading: true,
      clearSummaryError: true,
    ));

    final result = await statisticsRepository.getSummary(
      year: event.year,
      month: event.month,
    );
    result.fold(
      (failure) => emit(state.copyWith(
        summaryLoading: false,
        summaryError: failure.message,
      )),
      (summary) => emit(state.copyWith(
        summaryLoading: false,
        summary: summary,
      )),
    );
  }

  Future<void> _onLoadCategoryBreakdown(
    LoadCategoryBreakdown event,
    Emitter<StatisticsState> emit,
  ) async {
    emit(state.copyWith(
      categoryLoading: true,
      categoryType: event.type,
      clearCategoryError: true,
    ));

    final result = await statisticsRepository.getCategoryBreakdown(
      year: event.year,
      month: event.month,
      type: event.type,
    );
    result.fold(
      (failure) => emit(state.copyWith(
        categoryLoading: false,
        categoryError: failure.message,
      )),
      (stats) => emit(state.copyWith(
        categoryLoading: false,
        categoryStats: stats,
      )),
    );
  }

  Future<void> _onLoadMonthlyTrend(
    LoadMonthlyTrend event,
    Emitter<StatisticsState> emit,
  ) async {
    emit(state.copyWith(
      trendLoading: true,
      clearTrendError: true,
    ));

    final result =
        await statisticsRepository.getMonthlyTrend(months: event.months);
    result.fold(
      (failure) => emit(state.copyWith(
        trendLoading: false,
        trendError: failure.message,
      )),
      (trends) => emit(state.copyWith(
        trendLoading: false,
        trends: trends,
      )),
    );
  }
}
