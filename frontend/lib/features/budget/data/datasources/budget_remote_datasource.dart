import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/budget/data/models/budget_model.dart';

abstract class BudgetRemoteDataSource {
  Future<BudgetModel> createBudget(Map<String, dynamic> data);
  Future<List<BudgetModel>> getBudgets({required int year, required int month});
  Future<BudgetModel> updateBudget(String id, Map<String, dynamic> data);
  Future<void> deleteBudget(String id, {bool applyToFuture = false});
  Future<BudgetSummaryModel> getBudgetSummary({
    required int year,
    required int month,
  });
  Future<List<BudgetModel>> copyPreviousMonthBudgets({
    required int year,
    required int month,
  });
}

class BudgetRemoteDataSourceImpl implements BudgetRemoteDataSource {
  final ApiClient apiClient;

  BudgetRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<BudgetModel> createBudget(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.budgets,
      data: data,
    );
    return BudgetModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<BudgetModel>> getBudgets({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.budgets,
      queryParameters: {'year': year, 'month': month},
    );
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => BudgetModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<BudgetModel> updateBudget(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.budgets}/$id',
      data: data,
    );
    return BudgetModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteBudget(String id, {bool applyToFuture = false}) async {
    await apiClient.dio.delete(
      '${ApiEndpoints.budgets}/$id',
      queryParameters: applyToFuture ? {'applyToFuture': 'true'} : null,
    );
  }

  @override
  Future<BudgetSummaryModel> getBudgetSummary({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.dio.get(
      '${ApiEndpoints.budgets}/summary',
      queryParameters: {'year': year, 'month': month},
    );
    return BudgetSummaryModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<BudgetModel>> copyPreviousMonthBudgets({
    required int year,
    required int month,
  }) async {
    final yearMonth =
        '$year-${month.toString().padLeft(2, '0')}';
    final response = await apiClient.dio.post(
      '${ApiEndpoints.budgets}/copy-previous',
      data: {'yearMonth': yearMonth},
    );
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => BudgetModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
