import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/statistics/data/models/statistics_summary_model.dart';
import 'package:budget_book/features/statistics/data/models/category_statistics_model.dart';
import 'package:budget_book/features/statistics/data/models/monthly_trend_model.dart';
import 'package:budget_book/features/statistics/data/models/payment_method_statistics_model.dart';
import 'package:budget_book/features/statistics/data/models/period_summary_model.dart';

abstract class StatisticsRemoteDataSource {
  /// 회차 8 — 모든 필터 지원 확장
  Future<StatisticsSummaryModel> getSummary({
    required int year,
    required int month,
    String visibility = 'ALL',
    String? dateFrom,
    String? dateTo,
    String? categoryId,
    String? paymentMethodId,
    String? pocketId,
    Set<String> categoryIds = const {},
    Set<String> categoryGroupIds = const {},
    Set<String> paymentMethodIds = const {},
    Set<String> pocketIds = const {},
    int? amountMin,
    int? amountMax,
    String? keyword,
    Set<String> transactionTypes = const {},
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
    String? dateFrom,
    String? dateTo,
  });

  Future<PeriodSummaryModel> getPeriodSummary({
    required String dateFrom,
    required String dateTo,
    String? categoryId,
    Set<String> categoryIds = const {},
    Set<String> categoryGroupIds = const {},
    String? paymentMethodId,
    Set<String> paymentMethodIds = const {},
    String? pocketId,
    Set<String> pocketIds = const {},
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
    String? categoryId,
    String? paymentMethodId,
    String? pocketId,
    Set<String> categoryIds = const {},
    Set<String> categoryGroupIds = const {},
    Set<String> paymentMethodIds = const {},
    Set<String> pocketIds = const {},
    int? amountMin,
    int? amountMax,
    String? keyword,
    Set<String> transactionTypes = const {},
  }) async {
    final params = <String, dynamic>{
      'year': year,
      'month': month,
      'visibility': visibility,
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
      if (categoryId != null) 'categoryId': categoryId,
      if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
      if (pocketId != null) 'pocketId': pocketId,
      if (categoryIds.isNotEmpty) 'categoryIds': categoryIds.toList(),
      if (categoryGroupIds.isNotEmpty) 'categoryGroupIds': categoryGroupIds.toList(),
      if (paymentMethodIds.isNotEmpty) 'paymentMethodIds': paymentMethodIds.toList(),
      if (pocketIds.isNotEmpty) 'pocketIds': pocketIds.toList(),
      if (amountMin != null) 'amountMin': amountMin,
      if (amountMax != null) 'amountMax': amountMax,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (transactionTypes.isNotEmpty)
        'transactionTypes': transactionTypes.toList(),
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
      ApiEndpoints.statisticsPaymentMethods,
      queryParameters: params,
    );
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => PaymentMethodStatisticsModel.fromJson(
            e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PeriodSummaryModel> getPeriodSummary({
    required String dateFrom,
    required String dateTo,
    String? categoryId,
    Set<String> categoryIds = const {},
    Set<String> categoryGroupIds = const {},
    String? paymentMethodId,
    Set<String> paymentMethodIds = const {},
    String? pocketId,
    Set<String> pocketIds = const {},
  }) async {
    // PR-C3: 복수 필드 직렬화. ApiClient BaseOptions(listFormat: ListFormat.multi)
    // 에 의해 `?categoryIds=a&categoryIds=b` 형식으로 전달 (Spring 호환).
    final params = <String, dynamic>{
      'dateFrom': dateFrom,
      'dateTo': dateTo,
      if (categoryId != null) 'categoryId': categoryId,
      if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
      if (pocketId != null) 'pocketId': pocketId,
      if (categoryIds.isNotEmpty) 'categoryIds': categoryIds.toList(),
      if (categoryGroupIds.isNotEmpty)
        'categoryGroupIds': categoryGroupIds.toList(),
      if (paymentMethodIds.isNotEmpty)
        'paymentMethodIds': paymentMethodIds.toList(),
      if (pocketIds.isNotEmpty) 'pocketIds': pocketIds.toList(),
    };
    final response = await apiClient.dio.get(
      ApiEndpoints.statisticsPeriodSummary,
      queryParameters: params,
    );
    return PeriodSummaryModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
