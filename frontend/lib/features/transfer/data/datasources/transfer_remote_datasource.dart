import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/transaction/data/models/transaction_model.dart';
import 'package:budget_book/features/transfer/data/models/transfer_model.dart';

abstract class TransferRemoteDataSource {
  Future<List<TransferModel>> getTransfers({
    required int year,
    required int month,
    bool? reconciled,
  });
  Future<TransferModel> getTransfer(String id);
  Future<TransferModel> createTransfer(Map<String, dynamic> data);
  Future<TransferModel> createCardSettlement(Map<String, dynamic> data);
  Future<TransferModel> updateCardSettlement(
      String id, Map<String, dynamic> data);
  Future<TransferModel> updateTransfer(String id, Map<String, dynamic> data);

  /// 이체 → 거래 역변환. 서버가 원본 이체 삭제 + 거래 생성을 한 트랜잭션으로 처리하고
  /// **거래**를 돌려준다 (거래 → 이체 변환의 거울상).
  Future<TransactionModel> convertToTransaction(
      String id, Map<String, dynamic> data);

  Future<void> deleteTransfer(String id);
}

class TransferRemoteDataSourceImpl implements TransferRemoteDataSource {
  final ApiClient apiClient;

  TransferRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<TransferModel>> getTransfers({
    required int year,
    required int month,
    bool? reconciled,
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.transfers,
      queryParameters: {
        'year': year,
        'month': month,
        // V65 — false 도 의미가 있다("미기록만"). null 일 때만 생략.
        if (reconciled != null) 'reconciled': reconciled,
      },
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
  Future<TransferModel> createCardSettlement(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      '${ApiEndpoints.transfers}/card-settlement',
      data: data,
    );
    return TransferModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<TransferModel> updateCardSettlement(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.transfers}/card-settlement/$id',
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
  Future<TransactionModel> convertToTransaction(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      '${ApiEndpoints.transfers}/$id/convert-to-transaction',
      data: data,
    );
    return TransactionModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteTransfer(String id) async {
    await apiClient.dio.delete('${ApiEndpoints.transfers}/$id');
  }
}
