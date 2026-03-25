import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/transfer/data/models/transfer_model.dart';

abstract class TransferRemoteDataSource {
  Future<List<TransferModel>> getTransfers({
    required int year,
    required int month,
  });
  Future<TransferModel> getTransfer(String id);
  Future<TransferModel> createTransfer(Map<String, dynamic> data);
  Future<TransferModel> updateTransfer(String id, Map<String, dynamic> data);
  Future<void> deleteTransfer(String id);
}

class TransferRemoteDataSourceImpl implements TransferRemoteDataSource {
  final ApiClient apiClient;

  TransferRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<TransferModel>> getTransfers({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.transfers,
      queryParameters: {'year': year, 'month': month},
    );

    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => TransferModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TransferModel> getTransfer(String id) async {
    final response = await apiClient.dio.get(
      '${ApiEndpoints.transfers}/$id',
    );
    return TransferModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<TransferModel> createTransfer(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.transfers,
      data: data,
    );
    return TransferModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<TransferModel> updateTransfer(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.transfers}/$id',
      data: data,
    );
    return TransferModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteTransfer(String id) async {
    await apiClient.dio.delete('${ApiEndpoints.transfers}/$id');
  }
}
