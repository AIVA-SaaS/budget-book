import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/weekly_budget/data/datasources/weekly_budget_remote_datasource.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_overview.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/current_week_summary.dart';
import 'package:budget_book/features/weekly_budget/domain/repositories/weekly_budget_repository.dart';

class WeeklyBudgetRepositoryImpl implements WeeklyBudgetRepository {
  final WeeklyBudgetRemoteDataSource remoteDataSource;

  WeeklyBudgetRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, WeeklyOverview>> getWeeklyOverview(
      int year, int month) async {
    try {
      final result = await remoteDataSource.getWeeklyOverview(year, month);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, '주간 예산 정보를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, CurrentWeekSummary>> getCurrentWeekSummary() async {
    try {
      final result = await remoteDataSource.getCurrentWeekSummary();
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, '이번 주 예산 정보를 불러오지 못했습니다'));
    }
  }

  Failure _mapDioError(DioException e, String defaultMessage) {
    final errorData = e.response?.data?['error'];
    return ServerFailure(
      errorData?['message'] as String? ?? defaultMessage,
      errorData?['code'] as String?,
      e.response?.statusCode,
    );
  }
}
