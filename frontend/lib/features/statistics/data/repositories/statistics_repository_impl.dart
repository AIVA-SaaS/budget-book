import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/statistics/data/datasources/statistics_remote_datasource.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';

class StatisticsRepositoryImpl implements StatisticsRepository {
  final StatisticsRemoteDataSource remoteDataSource;

  StatisticsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, StatisticsSummary>> getSummary({
    required int year,
    required int month,
  }) async {
    try {
      final result = await remoteDataSource.getSummary(
        year: year,
        month: month,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, '통계 요약을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<CategoryStatistics>>> getCategoryBreakdown({
    required int year,
    required int month,
    String type = 'EXPENSE',
  }) async {
    try {
      final result = await remoteDataSource.getCategoryBreakdown(
        year: year,
        month: month,
        type: type,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, '카테고리별 통계를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<MonthlyTrend>>> getMonthlyTrend({
    int months = 6,
  }) async {
    try {
      final result = await remoteDataSource.getMonthlyTrend(months: months);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, '월별 추이를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<PaymentMethodStatistics>>>
      getPaymentMethodStats({
    required int year,
    required int month,
  }) async {
    try {
      final result = await remoteDataSource.getPaymentMethodStats(
        year: year,
        month: month,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, '결제수단별 통계를 불러오지 못했습니다'));
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
