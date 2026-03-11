import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/report/data/models/weekly_report_model.dart';
import 'package:budget_book/features/report/data/models/monthly_report_model.dart';

abstract class ReportRemoteDataSource {
  Future<WeeklyReportModel> getWeeklyReport(int year, int month, int week);
  Future<MonthlyReportModel> getMonthlyReport(int year, int month);
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final ApiClient apiClient;

  ReportRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<WeeklyReportModel> getWeeklyReport(
      int year, int month, int week) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.reportsWeekly,
      queryParameters: {'year': year, 'month': month, 'week': week},
    );
    return WeeklyReportModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<MonthlyReportModel> getMonthlyReport(int year, int month) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.reportsMonthly,
      queryParameters: {'year': year, 'month': month},
    );
    return MonthlyReportModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
