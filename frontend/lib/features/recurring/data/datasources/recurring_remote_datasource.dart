import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/recurring/data/models/recurring_transaction_model.dart';

abstract class RecurringRemoteDataSource {
  Future<List<RecurringTransactionModel>> getRecurringTransactions();
  Future<RecurringTransactionModel> createRecurringTransaction(
      Map<String, dynamic> data);
  Future<RecurringTransactionModel> updateRecurringTransaction(
      String id, Map<String, dynamic> data);
  Future<void> deleteRecurringTransaction(String id);
}

class RecurringRemoteDataSourceImpl implements RecurringRemoteDataSource {
  final ApiClient apiClient;

  RecurringRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<RecurringTransactionModel>> getRecurringTransactions() async {
    final response =
        await apiClient.dio.get(ApiEndpoints.recurringTransactions);
    final list = response.data['data'] as List<dynamic>;
    return list
        .map((e) =>
            RecurringTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RecurringTransactionModel> createRecurringTransaction(
      Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.recurringTransactions,
      data: data,
    );
    return RecurringTransactionModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<RecurringTransactionModel> updateRecurringTransaction(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.recurringTransactions}/$id',
      data: data,
    );
    return RecurringTransactionModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteRecurringTransaction(String id) async {
    await apiClient.dio
        .delete('${ApiEndpoints.recurringTransactions}/$id');
  }
}
