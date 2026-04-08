import 'package:equatable/equatable.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';

class StatisticsState extends Equatable {
  final int year;
  final int month;
  final String categoryType;
  /// Visibility filter: 'ALL', 'SHARED', or 'PRIVATE'
  final String visibilityFilter;
  /// Custom date range filter (overrides year/month when set)
  final String? dateFrom;
  final String? dateTo;
  final String? dateRangeLabel;

  // Summary
  final bool summaryLoading;
  final StatisticsSummary? summary;
  final String? summaryError;

  // Category breakdown
  final bool categoryLoading;
  final List<CategoryStatistics> categoryStats;
  final String? categoryError;

  // Monthly trend
  final bool trendLoading;
  final List<MonthlyTrend> trends;
  final String? trendError;

  // Year comparison
  final bool comparisonLoading;
  final StatisticsSummary? currentYearSummary;
  final StatisticsSummary? previousYearSummary;
  final String? comparisonError;

  // Payment method stats
  final bool paymentMethodLoading;
  final List<PaymentMethodStatistics> paymentMethodStats;
  final String? paymentMethodError;

  const StatisticsState({
    required this.year,
    required this.month,
    this.categoryType = 'EXPENSE',
    this.visibilityFilter = 'ALL',
    this.dateFrom,
    this.dateTo,
    this.dateRangeLabel,
    this.summaryLoading = false,
    this.summary,
    this.summaryError,
    this.categoryLoading = false,
    this.categoryStats = const [],
    this.categoryError,
    this.trendLoading = false,
    this.trends = const [],
    this.trendError,
    this.comparisonLoading = false,
    this.currentYearSummary,
    this.previousYearSummary,
    this.comparisonError,
    this.paymentMethodLoading = false,
    this.paymentMethodStats = const [],
    this.paymentMethodError,
  });

  bool get isAllLoading => summaryLoading && categoryLoading && trendLoading;

  /// Whether a custom date range is active
  bool get hasDateRange => dateFrom != null && dateTo != null;

  StatisticsState copyWith({
    int? year,
    int? month,
    String? categoryType,
    String? visibilityFilter,
    String? dateFrom,
    String? dateTo,
    String? dateRangeLabel,
    bool clearDateRange = false,
    bool? summaryLoading,
    StatisticsSummary? summary,
    String? summaryError,
    bool clearSummaryError = false,
    bool? categoryLoading,
    List<CategoryStatistics>? categoryStats,
    String? categoryError,
    bool clearCategoryError = false,
    bool? trendLoading,
    List<MonthlyTrend>? trends,
    String? trendError,
    bool clearTrendError = false,
    bool? comparisonLoading,
    StatisticsSummary? currentYearSummary,
    StatisticsSummary? previousYearSummary,
    String? comparisonError,
    bool clearComparisonError = false,
    bool? paymentMethodLoading,
    List<PaymentMethodStatistics>? paymentMethodStats,
    String? paymentMethodError,
    bool clearPaymentMethodError = false,
  }) {
    return StatisticsState(
      year: year ?? this.year,
      month: month ?? this.month,
      categoryType: categoryType ?? this.categoryType,
      visibilityFilter: visibilityFilter ?? this.visibilityFilter,
      dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
      dateRangeLabel: clearDateRange ? null : (dateRangeLabel ?? this.dateRangeLabel),
      summaryLoading: summaryLoading ?? this.summaryLoading,
      summary: summary ?? this.summary,
      summaryError:
          clearSummaryError ? null : (summaryError ?? this.summaryError),
      categoryLoading: categoryLoading ?? this.categoryLoading,
      categoryStats: categoryStats ?? this.categoryStats,
      categoryError:
          clearCategoryError ? null : (categoryError ?? this.categoryError),
      trendLoading: trendLoading ?? this.trendLoading,
      trends: trends ?? this.trends,
      trendError: clearTrendError ? null : (trendError ?? this.trendError),
      comparisonLoading: comparisonLoading ?? this.comparisonLoading,
      currentYearSummary: currentYearSummary ?? this.currentYearSummary,
      previousYearSummary: previousYearSummary ?? this.previousYearSummary,
      comparisonError: clearComparisonError
          ? null
          : (comparisonError ?? this.comparisonError),
      paymentMethodLoading: paymentMethodLoading ?? this.paymentMethodLoading,
      paymentMethodStats: paymentMethodStats ?? this.paymentMethodStats,
      paymentMethodError: clearPaymentMethodError
          ? null
          : (paymentMethodError ?? this.paymentMethodError),
    );
  }

  @override
  List<Object?> get props => [
        year,
        month,
        categoryType,
        visibilityFilter,
        dateFrom,
        dateTo,
        dateRangeLabel,
        summaryLoading,
        summary,
        summaryError,
        categoryLoading,
        categoryStats,
        categoryError,
        trendLoading,
        trends,
        trendError,
        comparisonLoading,
        currentYearSummary,
        previousYearSummary,
        comparisonError,
        paymentMethodLoading,
        paymentMethodStats,
        paymentMethodError,
      ];
}
