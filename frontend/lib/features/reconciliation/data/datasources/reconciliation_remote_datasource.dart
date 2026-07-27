import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/features/reconciliation/data/models/reconciliation_model.dart';

abstract class ReconciliationRemoteDataSource {
  Future<List<ReconciliationModel>> getReconciliations({
    required int year,
    required int month,
  });

  Future<ReconciliationDetailModel> getReconciliation(String id);

  Future<ReconciliationDetailModel> createReconciliation({
    required String yearMonth,
    String? label,
    List<String> transactionIds,
    List<String> transferIds,
  });

  Future<ReconciliationDetailModel> updateReconciliation({
    required String id,
    String? label,
    List<String> addTransactionIds,
    List<String> addTransferIds,
    List<String> removeItemIds,
  });

  Future<void> deleteReconciliation(String id);

  Future<ReconciliationSummaryModel> getSummary({
    required int year,
    required int month,
  });
}

class ReconciliationRemoteDataSourceImpl implements ReconciliationRemoteDataSource {
  final ApiClient apiClient;

  ReconciliationRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<ReconciliationModel>> getReconciliations({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.reconciliations,
      queryParameters: {'year': year, 'month': month},
    );
    return (response.data['data'] as List<dynamic>)
        .map((e) => ReconciliationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ReconciliationDetailModel> getReconciliation(String id) async {
    final response =
        await apiClient.dio.get('${ApiEndpoints.reconciliations}/$id');
    return ReconciliationDetailModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<ReconciliationDetailModel> createReconciliation({
    required String yearMonth,
    String? label,
    List<String> transactionIds = const [],
    List<String> transferIds = const [],
  }) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.reconciliations,
      data: {
        'yearMonth': yearMonth,
        if (label != null && label.isNotEmpty) 'label': label,
        'transactionIds': transactionIds,
        'transferIds': transferIds,
      },
    );
    return ReconciliationDetailModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<ReconciliationDetailModel> updateReconciliation({
    required String id,
    String? label,
    List<String> addTransactionIds = const [],
    List<String> addTransferIds = const [],
    List<String> removeItemIds = const [],
  }) async {
    final response = await apiClient.dio.patch(
      '${ApiEndpoints.reconciliations}/$id',
      data: {
        if (label != null) 'label': label,
        if (addTransactionIds.isNotEmpty) 'addTransactionIds': addTransactionIds,
        if (addTransferIds.isNotEmpty) 'addTransferIds': addTransferIds,
        if (removeItemIds.isNotEmpty) 'removeItemIds': removeItemIds,
      },
    );
    return ReconciliationDetailModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteReconciliation(String id) async {
    await apiClient.dio.delete('${ApiEndpoints.reconciliations}/$id');
  }

  @override
  Future<ReconciliationSummaryModel> getSummary({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.reconciliationSummary,
      queryParameters: {'year': year, 'month': month},
    );
    return ReconciliationSummaryModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
