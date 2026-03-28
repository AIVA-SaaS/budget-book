import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/spending_plan/data/models/spending_plan_model.dart';

/// Raw API response containing plans and summary.
class SpendingPlanListRawResponse {
  final List<SpendingPlanModel> plans;
  final SpendingPlanSummaryModel summary;

  SpendingPlanListRawResponse({
    required this.plans,
    required this.summary,
  });
}

abstract class SpendingPlanRemoteDataSource {
  Future<SpendingPlanListRawResponse> getSpendingPlans({
    String? startDate,
    String? endDate,
    String? status,
  });

  Future<SpendingPlanModel> createSpendingPlan(Map<String, dynamic> data);

  Future<SpendingPlanModel> updateSpendingPlan(
      String id, Map<String, dynamic> data);

  Future<void> deleteSpendingPlan(String id);

  Future<SpendingPlanModel> completePlan(
      String id, Map<String, dynamic> data);

  Future<SpendingPlanModel> skipPlan(String id);

  Future<List<SpendingPlanSuggestionModel>> getSuggestions({
    String? categoryId,
    int? amount,
    String? date,
  });
}

class SpendingPlanRemoteDataSourceImpl implements SpendingPlanRemoteDataSource {
  final ApiClient apiClient;

  SpendingPlanRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<SpendingPlanListRawResponse> getSpendingPlans({
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    if (status != null) queryParams['status'] = status;

    final response = await apiClient.dio.get(
      ApiEndpoints.spendingPlans,
      queryParameters: queryParams,
    );

    final responseData = response.data['data'] as Map<String, dynamic>;
    final plansJson = responseData['plans'] as List<dynamic>;
    final summaryJson = responseData['summary'] as Map<String, dynamic>;

    return SpendingPlanListRawResponse(
      plans: plansJson
          .map((e) => SpendingPlanModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: SpendingPlanSummaryModel.fromJson(summaryJson),
    );
  }

  @override
  Future<SpendingPlanModel> createSpendingPlan(
      Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.spendingPlans,
      data: data,
    );
    return SpendingPlanModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<SpendingPlanModel> updateSpendingPlan(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.spendingPlans}/$id',
      data: data,
    );
    return SpendingPlanModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteSpendingPlan(String id) async {
    await apiClient.dio.delete('${ApiEndpoints.spendingPlans}/$id');
  }

  @override
  Future<SpendingPlanModel> completePlan(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.patch(
      '${ApiEndpoints.spendingPlans}/$id/complete',
      data: data,
    );
    return SpendingPlanModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<SpendingPlanModel> skipPlan(String id) async {
    final response = await apiClient.dio.patch(
      '${ApiEndpoints.spendingPlans}/$id/skip',
    );
    return SpendingPlanModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<SpendingPlanSuggestionModel>> getSuggestions({
    String? categoryId,
    int? amount,
    String? date,
  }) async {
    final queryParams = <String, dynamic>{};
    if (categoryId != null) queryParams['categoryId'] = categoryId;
    if (amount != null) queryParams['amount'] = amount;
    if (date != null) queryParams['date'] = date;

    final response = await apiClient.dio.get(
      '${ApiEndpoints.spendingPlans}/suggestions',
      queryParameters: queryParams,
    );

    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) =>
            SpendingPlanSuggestionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
