import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/statistics/data/datasources/statistics_remote_datasource.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/period_summary.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';

class StatisticsRepositoryImpl implements StatisticsRepository {
  final StatisticsRemoteDataSource remoteDataSource;

  StatisticsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, StatisticsSummary>> getSummary({
    required int year,
    required int month,
    String visibility = 'ALL',
    String? dateFrom,
    String? dateTo,
    String? categoryId,
    String? paymentMethodId,
    String? pocketId,
    Set<String> categoryIds = const {},
    Set<String> categoryGroupIds = const {},
    Set<String> paymentMethodIds = const {},
    Set<String> pocketIds = const {},
    int? amountMin,
    int? amountMax,
    String? keyword,
    Set<String> transactionTypes = const {},
  }) async {
    try {
      final result = await remoteDataSource.getSummary(
        year: year, month: month, visibility: visibility,
        dateFrom: dateFrom, dateTo: dateTo,
        categoryId: categoryId,
        paymentMethodId: paymentMethodId,
        pocketId: pocketId,
        categoryIds: categoryIds,
        categoryGroupIds: categoryGroupIds,
        paymentMethodIds: paymentMethodIds,
        pocketIds: pocketIds,
        amountMin: amountMin,
        amountMax: amountMax,
        keyword: keyword,
        transactionTypes: transactionTypes,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '통계 요약을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('통계 요약을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<CategoryStatistics>>> getCategoryBreakdown({
    required int year,
    required int month,
    String type = 'EXPENSE',
    String visibility = 'ALL',
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final result = await remoteDataSource.getCategoryBreakdown(
        year: year, month: month, type: type, visibility: visibility,
        dateFrom: dateFrom, dateTo: dateTo,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '카테고리별 통계를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('카테고리별 통계를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<MonthlyTrend>>> getMonthlyTrend({
    int months = 6,
    String visibility = 'ALL',
  }) async {
    try {
      final result = await remoteDataSource.getMonthlyTrend(
        months: months, visibility: visibility,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '월별 추이를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('월별 추이를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<PaymentMethodStatistics>>>
      getPaymentMethodStats({
    required int year,
    required int month,
    String visibility = 'ALL',
  }) async {
    try {
      final result = await remoteDataSource.getPaymentMethodStats(
        year: year, month: month, visibility: visibility,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '결제수단별 통계를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('결제수단별 통계를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, PeriodSummary>> getPeriodSummary({
    required String dateFrom,
    required String dateTo,
    String? categoryId,
    Set<String> categoryIds = const {},
    Set<String> categoryGroupIds = const {},
    String? paymentMethodId,
    Set<String> paymentMethodIds = const {},
    String? pocketId,
    Set<String> pocketIds = const {},
  }) async {
    try {
      final result = await remoteDataSource.getPeriodSummary(
        dateFrom: dateFrom,
        dateTo: dateTo,
        categoryId: categoryId,
        categoryIds: categoryIds,
        categoryGroupIds: categoryGroupIds,
        paymentMethodId: paymentMethodId,
        paymentMethodIds: paymentMethodIds,
        pocketId: pocketId,
        pocketIds: pocketIds,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '기간별 통계를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('기간별 통계를 불러오지 못했습니다'));
    }
  }
}
