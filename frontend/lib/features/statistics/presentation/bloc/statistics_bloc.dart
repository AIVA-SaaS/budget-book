import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_filter.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';
import 'statistics_event.dart';
import 'statistics_state.dart';

class StatisticsBloc extends Bloc<StatisticsEvent, StatisticsState> {
  final StatisticsRepository statisticsRepository;

  /// 현재 전체 통계 필터 상태의 단일 스냅샷.
  /// TransactionBloc.currentFilter 와 같은 패턴 — MonthSyncHandler 등 외부 consumer 가
  /// 개별 필드(visibilityFilter/dateFrom/dateTo) 를 따로 꺼내지 말고 이 getter 사용.
  /// 신규 필터 추가 시 StatisticsFilter / StatisticsState / 이 getter 를 동시 수정.
  StatisticsFilter get currentFilter => StatisticsFilter(
        categoryType: state.categoryType,
        visibilityFilter: state.visibilityFilter,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
        dateRangeLabel: state.dateRangeLabel,
      );

  StatisticsBloc({required this.statisticsRepository})
      : super(StatisticsState(
          year: DateTime.now().year,
          month: DateTime.now().month,
        )) {
    on<LoadAllStatistics>(_onLoadAll);
    on<LoadSummary>(_onLoadSummary);
    on<LoadCategoryBreakdown>(_onLoadCategoryBreakdown);
    on<LoadMonthlyTrend>(_onLoadMonthlyTrend);
    on<LoadYearComparison>(_onLoadYearComparison);
    on<LoadPaymentMethodStats>(_onLoadPaymentMethodStats);
    on<ChangeVisibilityFilter>(_onChangeVisibilityFilter);
    on<SetDateRangeFilter>(_onSetDateRangeFilter);
    on<ClearDateRangeFilter>(_onClearDateRangeFilter);
  }

  void _onChangeVisibilityFilter(
    ChangeVisibilityFilter event,
    Emitter<StatisticsState> emit,
  ) {
    emit(state.copyWith(visibilityFilter: event.visibility));
    // 모든 sub-tab 의 데이터를 visibility 변경에 맞게 reload.
    // (이전: LoadAllStatistics 만 호출 → 결제수단/연간비교 stale 회귀)
    add(LoadAllStatistics(year: state.year, month: state.month));
    add(LoadPaymentMethodStats(year: state.year, month: state.month));
    add(LoadYearComparison(year: state.year, month: state.month));
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

    try {
      // Load all three API calls in parallel using Future.wait
      final vis = state.visibilityFilter;
      final df = state.dateFrom;
      final dt = state.dateTo;
      final results = await Future.wait([
        statisticsRepository.getSummary(
          year: event.year,
          month: event.month,
          visibility: vis,
          dateFrom: df,
          dateTo: dt,
        ),
        statisticsRepository.getCategoryBreakdown(
          year: event.year,
          month: event.month,
          type: state.categoryType,
          visibility: vis,
          dateFrom: df,
          dateTo: dt,
        ),
        statisticsRepository.getMonthlyTrend(visibility: vis),
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
    } catch (e) {
      emit(state.copyWith(
        summaryLoading: false,
        categoryLoading: false,
        trendLoading: false,
        summaryError: '예기치 않은 오류가 발생했습니다',
        categoryError: '예기치 않은 오류가 발생했습니다',
        trendError: '예기치 않은 오류가 발생했습니다',
      ));
    }
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

    try {
      final result = await statisticsRepository.getSummary(
        year: event.year,
        month: event.month,
        visibility: state.visibilityFilter,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
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
    } catch (e) {
      emit(state.copyWith(
        summaryLoading: false,
        summaryError: '예기치 않은 오류가 발생했습니다',
      ));
    }
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

    try {
      final result = await statisticsRepository.getCategoryBreakdown(
        year: event.year,
        month: event.month,
        type: event.type,
        visibility: state.visibilityFilter,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
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
    } catch (e) {
      emit(state.copyWith(
        categoryLoading: false,
        categoryError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }

  Future<void> _onLoadMonthlyTrend(
    LoadMonthlyTrend event,
    Emitter<StatisticsState> emit,
  ) async {
    emit(state.copyWith(
      trendLoading: true,
      clearTrendError: true,
    ));

    try {
      final result = await statisticsRepository.getMonthlyTrend(
        months: event.months,
        visibility: state.visibilityFilter,
      );
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
    } catch (e) {
      emit(state.copyWith(
        trendLoading: false,
        trendError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }

  Future<void> _onLoadYearComparison(
    LoadYearComparison event,
    Emitter<StatisticsState> emit,
  ) async {
    emit(state.copyWith(
      comparisonLoading: true,
      clearComparisonError: true,
    ));

    try {
      // Load current year and previous year summary in parallel.
      // visibility 필터 반영 — 변경 시 ChangeVisibilityFilter 가 fire 함.
      final vis = state.visibilityFilter;
      final results = await Future.wait([
        statisticsRepository.getSummary(
            year: event.year, month: event.month, visibility: vis),
        statisticsRepository.getSummary(
            year: event.year - 1, month: event.month, visibility: vis),
      ]);

      StatisticsSummary? currentSummary;
      StatisticsSummary? previousSummary;
      String? error;

      results[0].fold(
        (failure) => error = failure.message,
        (data) => currentSummary = data,
      );

      results[1].fold(
        (failure) {
          // Previous year data may not exist - that's ok
          previousSummary = null;
        },
        (data) => previousSummary = data,
      );

      if (error != null) {
        emit(state.copyWith(
          comparisonLoading: false,
          comparisonError: error,
        ));
      } else {
        emit(state.copyWith(
          comparisonLoading: false,
          currentYearSummary: currentSummary,
          previousYearSummary: previousSummary,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        comparisonLoading: false,
        comparisonError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }

  Future<void> _onLoadPaymentMethodStats(
    LoadPaymentMethodStats event,
    Emitter<StatisticsState> emit,
  ) async {
    emit(state.copyWith(
      paymentMethodLoading: true,
      clearPaymentMethodError: true,
    ));

    try {
      final result = await statisticsRepository.getPaymentMethodStats(
        year: event.year,
        month: event.month,
        visibility: state.visibilityFilter,
      );
      result.fold(
        (failure) => emit(state.copyWith(
          paymentMethodLoading: false,
          paymentMethodError: failure.message,
        )),
        (stats) => emit(state.copyWith(
          paymentMethodLoading: false,
          paymentMethodStats: stats,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        paymentMethodLoading: false,
        paymentMethodError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }

  void _onSetDateRangeFilter(
    SetDateRangeFilter event,
    Emitter<StatisticsState> emit,
  ) {
    emit(state.copyWith(
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      dateRangeLabel: event.label,
    ));
    add(LoadAllStatistics(year: state.year, month: state.month));
  }

  void _onClearDateRangeFilter(
    ClearDateRangeFilter event,
    Emitter<StatisticsState> emit,
  ) {
    emit(state.copyWith(clearDateRange: true));
    add(LoadAllStatistics(year: state.year, month: state.month));
  }
}
