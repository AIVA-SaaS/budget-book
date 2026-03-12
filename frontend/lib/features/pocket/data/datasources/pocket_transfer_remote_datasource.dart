import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/pocket/data/models/pocket_transfer_model.dart';

abstract class PocketTransferRemoteDataSource {
  Future<List<PocketTransferModel>> getPocketTransfers({
    String? fromPocketId,
    String? toPocketId,
    String? startDate,
    String? endDate,
  });
  Future<PocketTransferModel> createPocketTransfer(
      Map<String, dynamic> data);
}

class PocketTransferRemoteDataSourceImpl
    implements PocketTransferRemoteDataSource {
  final ApiClient apiClient;

  PocketTransferRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<PocketTransferModel>> getPocketTransfers({
    String? fromPocketId,
    String? toPocketId,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (fromPocketId != null) queryParams['fromPocketId'] = fromPocketId;
    if (toPocketId != null) queryParams['toPocketId'] = toPocketId;
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final response = await apiClient.dio.get(
      ApiEndpoints.pocketTransfers,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final list = response.data['data'] as List<dynamic>;
    return list
        .map((e) =>
            PocketTransferModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PocketTransferModel> createPocketTransfer(
      Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.pocketTransfers,
      data: data,
    );
    return PocketTransferModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
