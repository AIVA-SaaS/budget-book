import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/insurance/data/models/insurance_model.dart';

abstract class InsuranceRemoteDataSource {
  Future<List<InsuranceModel>> getInsurances({bool? active});
  Future<InsuranceModel> createInsurance(Map<String, dynamic> data);
  Future<InsuranceModel> updateInsurance(String id, Map<String, dynamic> data);
  Future<void> deleteInsurance(String id);
  Future<InsuranceSummaryModel> getInsuranceSummary({
    required int year,
    required int month,
  });
}

class InsuranceRemoteDataSourceImpl implements InsuranceRemoteDataSource {
  final ApiClient apiClient;

  InsuranceRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<InsuranceModel>> getInsurances({bool? active}) async {
    final queryParams = <String, dynamic>{};
    if (active != null) queryParams['active'] = active;

    final response = await apiClient.dio.get(
      ApiEndpoints.insurances,
      queryParameters: queryParams,
    );

    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => InsuranceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<InsuranceModel> createInsurance(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.insurances,
      data: data,
    );
    return InsuranceModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<InsuranceModel> updateInsurance(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.insurances}/$id',
      data: data,
    );
    return InsuranceModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteInsurance(String id) async {
    await apiClient.dio.delete('${ApiEndpoints.insurances}/$id');
  }

  @override
  Future<InsuranceSummaryModel> getInsuranceSummary({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.dio.get(
      '${ApiEndpoints.insurances}/summary',
      queryParameters: {'year': year, 'month': month},
    );
    return InsuranceSummaryModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
