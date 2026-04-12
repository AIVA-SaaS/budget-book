import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/ai/data/models/ai_classify_model.dart';
import 'package:budget_book/features/ai/data/models/ai_insight_model.dart';
import 'package:budget_book/features/ai/data/models/budget_suggestion_model.dart';

abstract class AiRemoteDataSource {
  Future<List<AiClassifyModel>> classify(String description, String type);
  Future<AiInsightsResponseModel> getInsights(int year, int month);
  Future<List<BudgetSuggestionModel>> getBudgetSuggestions();
}

class AiRemoteDataSourceImpl implements AiRemoteDataSource {
  final ApiClient apiClient;

  AiRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<AiClassifyModel>> classify(String description, String type) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.smartClassify,
      queryParameters: {'description': description, 'type': type},
    );
    final data = response.data['data'];
    if (data is List) {
      return data
          .map((e) => AiClassifyModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    // Fallback: single result wrapped in list
    if (data is Map<String, dynamic>) {
      return [AiClassifyModel.fromJson(data)];
    }
    return [];
  }

  @override
  Future<AiInsightsResponseModel> getInsights(int year, int month) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.smartInsights,
      queryParameters: {'year': year, 'month': month},
    );
    return AiInsightsResponseModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<BudgetSuggestionModel>> getBudgetSuggestions() async {
    final response = await apiClient.dio.get(
      ApiEndpoints.smartBudgetSuggestions,
    );
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => BudgetSuggestionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
