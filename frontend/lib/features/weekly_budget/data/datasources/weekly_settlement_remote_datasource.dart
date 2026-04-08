import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/weekly_budget/data/models/weekly_settlement_model.dart';

abstract class WeeklySettlementRemoteDataSource {
  Future<WeeklySettlementOverviewModel> getSettlements(int year, int month);
  Future<void> settle(List<String> budgetIds, int weekNumber);
  Future<void> unsettle(List<String> budgetIds, int weekNumber);
}

class WeeklySettlementRemoteDataSourceImpl
    implements WeeklySettlementRemoteDataSource {
  final ApiClient apiClient;

  WeeklySettlementRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<WeeklySettlementOverviewModel> getSettlements(
      int year, int month) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.weeklySettlements,
      queryParameters: {'year': year, 'month': month},
    );
    return WeeklySettlementOverviewModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> settle(List<String> budgetIds, int weekNumber) async {
    await apiClient.dio.post(
      ApiEndpoints.weeklySettlementsSettle,
      data: {'budgetIds': budgetIds, 'weekNumber': weekNumber},
    );
  }

  @override
  Future<void> unsettle(List<String> budgetIds, int weekNumber) async {
    await apiClient.dio.post(
      ApiEndpoints.weeklySettlementsUnsettle,
      data: {'budgetIds': budgetIds, 'weekNumber': weekNumber},
    );
  }
}
