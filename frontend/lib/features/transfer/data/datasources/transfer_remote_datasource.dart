import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/transaction/data/models/transaction_model.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
import 'package:budget_book/features/transfer/data/models/transfer_model.dart';

abstract class TransferRemoteDataSource {
  /// [filter] 를 주면 장부 필터가 서버에서 적용된다 (2026-08-12).
  /// 직렬화는 `TransactionFilter.toQueryParams()` **단일 경로**를 재사용한다 —
  /// 이체용 직렬화를 따로 만들면 그것이 다음 drift 다.
  Future<List<TransferModel>> getTransfers({
    required int year,
    required int month,
    bool? reconciled,
    TransactionFilter? filter,
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
    TransactionFilter? filter,
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.transfers,
      queryParameters: {
        'year': year,
        'month': month,
        // 장부 필터 (있으면). dateFrom/dateTo 가 실리면 서버가 year/month 대신 그 범위를 쓴다.
        ...?filter?.toQueryParams(),
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
