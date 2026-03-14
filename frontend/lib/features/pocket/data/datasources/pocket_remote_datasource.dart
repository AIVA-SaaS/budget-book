import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/pocket/data/models/pocket_model.dart';
import 'package:budget_book/features/pocket/data/models/distribute_result_model.dart';

abstract class PocketRemoteDataSource {
  Future<List<PocketModel>> getPockets();
  Future<PocketModel> createPocket(Map<String, dynamic> data);
  Future<PocketModel> updatePocket(String id, Map<String, dynamic> data);
  Future<void> deletePocket(String id);
  Future<DistributeResultModel> distributeIncome(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getDistributionRatios();
  Future<void> saveDistributionRatios(List<Map<String, dynamic>> ratios);
}

class PocketRemoteDataSourceImpl implements PocketRemoteDataSource {
  final ApiClient apiClient;

  PocketRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<PocketModel>> getPockets() async {
    final response = await apiClient.dio.get(ApiEndpoints.pockets);
    final list = response.data['data'] as List<dynamic>;
    return list
        .map((e) => PocketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PocketModel> createPocket(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.pockets,
      data: data,
    );
    return PocketModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<PocketModel> updatePocket(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.pockets}/$id',
      data: data,
    );
    return PocketModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deletePocket(String id) async {
    await apiClient.dio.delete('${ApiEndpoints.pockets}/$id');
  }

  @override
  Future<DistributeResultModel> distributeIncome(
      Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.pocketsDistribute,
      data: data,
    );
    return DistributeResultModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getDistributionRatios() async {
    final response = await apiClient.dio.get(
      ApiEndpoints.pocketsDistributionRatios,
    );
    final list = response.data['data'] as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> saveDistributionRatios(
      List<Map<String, dynamic>> ratios) async {
    await apiClient.dio.put(
      ApiEndpoints.pocketsDistributionRatios,
      data: ratios,
    );
  }
}
