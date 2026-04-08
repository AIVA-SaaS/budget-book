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
    String visibility = 'ALL',
    String? dateFrom,
    String? dateTo,
  });

  Future<List<CategoryStatisticsModel>> getCategoryBreakdown({
    required int year,
    required int month,
    String type = 'EXPENSE',
    String visibility = 'ALL',
    String? dateFrom,
    String? dateTo,
  });

  Future<List<MonthlyTrendModel>> getMonthlyTrend({
    int months = 6,
    String visibility = 'ALL',
  });

  Future<List<PaymentMethodStatisticsModel>> getPaymentMethodStats({
    required int year,
    required int month,
    String visibility = 'ALL',
  });
}

class StatisticsRemoteDataSourceImpl implements StatisticsRemoteDataSource {
  final ApiClient apiClient;

  StatisticsRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<StatisticsSummaryModel> getSummary({
    required int year,
    required int month,
    String visibility = 'ALL',
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, dynamic>{
      'year': year,
      'month': month,
      'visibility': visibility,
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    };
    final response = await apiClient.dio.get(
      ApiEndpoints.statisticsSummary,
      queryParameters: params,
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
    String visibility = 'ALL',
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, dynamic>{
      'year': year,
      'month': month,
      'type': type,
      'visibility': visibility,
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    };
    final response = await apiClient.dio.get(
      ApiEndpoints.statisticsByCategory,
      queryParameters: params,
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
    String visibility = 'ALL',
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.statisticsMonthlyTrend,
      queryParameters: {'months': months, 'visibility': visibility},
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
    String visibility = 'ALL',
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.statisticsPaymentMethods,
      queryParameters: {'year': year, 'month': month, 'visibility': visibility},
    );
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => PaymentMethodStatisticsModel.fromJson(
            e as Map<String, dynamic>))
        .toList();
  }
}
