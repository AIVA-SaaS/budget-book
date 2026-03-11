import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/weekly_budget/data/models/weekly_overview_model.dart';
import 'package:budget_book/features/weekly_budget/data/models/current_week_summary_model.dart';

abstract class WeeklyBudgetRemoteDataSource {
  Future<WeeklyOverviewModel> getWeeklyOverview(int year, int month);
  Future<CurrentWeekSummaryModel> getCurrentWeekSummary();
}

class WeeklyBudgetRemoteDataSourceImpl
    implements WeeklyBudgetRemoteDataSource {
  final ApiClient apiClient;

  WeeklyBudgetRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<WeeklyOverviewModel> getWeeklyOverview(int year, int month) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.weeklyBudgets,
      queryParameters: {'year': year, 'month': month},
    );
    return WeeklyOverviewModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<CurrentWeekSummaryModel> getCurrentWeekSummary() async {
    final response = await apiClient.dio.get(
      ApiEndpoints.weeklyBudgetCurrent,
    );
    return CurrentWeekSummaryModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
