import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/ai/data/models/ai_classify_model.dart';
import 'package:budget_book/features/ai/data/models/ai_insight_model.dart';

abstract class AiRemoteDataSource {
  Future<AiClassifyModel> classify(String description, String type);
  Future<AiInsightsResponseModel> getInsights(int year, int month);
}

class AiRemoteDataSourceImpl implements AiRemoteDataSource {
  final ApiClient apiClient;

  AiRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<AiClassifyModel> classify(String description, String type) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.aiClassify,
      data: {'description': description, 'type': type},
    );
    return AiClassifyModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<AiInsightsResponseModel> getInsights(int year, int month) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.aiInsights,
      queryParameters: {'year': year, 'month': month},
    );
    return AiInsightsResponseModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
