import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/statistics/data/models/statistics_summary_model.dart';
import 'package:budget_book/features/statistics/data/models/category_statistics_model.dart';
import 'package:budget_book/features/statistics/data/models/monthly_trend_model.dart';
import 'package:budget_book/features/statistics/data/models/payment_method_statistics_model.dart';

abstract class StatisticsRemoteDataSource {
  Future<StatisticsSummaryModel> getSummary({
    required int year,
    required int month,
  });

  Future<List<CategoryStatisticsModel>> getCategoryBreakdown({
    required int year,
    required int month,
    String type = 'EXPENSE',
  });

  Future<List<MonthlyTrendModel>> getMonthlyTrend({
    int months = 6,
  });

  Future<List<PaymentMethodStatisticsModel>> getPaymentMethodStats({
    required int year,
    required int month,
  });
}

class StatisticsRemoteDataSourceImpl implements StatisticsRemoteDataSource {
  final ApiClient apiClient;

  StatisticsRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<StatisticsSummaryModel> getSummary({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.statisticsSummary,
      queryParameters: {'year': year, 'month': month},
    );
    return StatisticsSummaryModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<CategoryStatisticsModel>> getCategoryBreakdown({
    required int year,
    required int month,
    String type = 'EXPENSE',
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.statisticsByCategory,
      queryParameters: {'year': year, 'month': month, 'type': type},
    );
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) =>
            CategoryStatisticsModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<MonthlyTrendModel>> getMonthlyTrend({
    int months = 6,
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.statisticsMonthlyTrend,
      queryParameters: {'months': months},
    );
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => MonthlyTrendModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<PaymentMethodStatisticsModel>> getPaymentMethodStats({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.statisticsPaymentMethods,
      queryParameters: {'yearMonth': '$year-${month.toString().padLeft(2, '0')}'},
    );
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => PaymentMethodStatisticsModel.fromJson(
            e as Map<String, dynamic>))
        .toList();
  }
}
