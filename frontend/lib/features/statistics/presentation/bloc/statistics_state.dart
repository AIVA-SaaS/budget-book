import 'package:equatable/equatable.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';

class StatisticsState extends Equatable {
  final int year;
  final int month;
  final String categoryType;

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

  const StatisticsState({
    required this.year,
    required this.month,
    this.categoryType = 'EXPENSE',
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
  });

  bool get isAllLoading => summaryLoading && categoryLoading && trendLoading;

  StatisticsState copyWith({
    int? year,
    int? month,
    String? categoryType,
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
  }) {
    return StatisticsState(
      year: year ?? this.year,
      month: month ?? this.month,
      categoryType: categoryType ?? this.categoryType,
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
    );
  }

  @override
  List<Object?> get props => [
        year,
        month,
        categoryType,
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
      ];
}
