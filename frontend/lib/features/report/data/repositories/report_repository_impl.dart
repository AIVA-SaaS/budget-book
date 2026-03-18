import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/report/data/datasources/report_remote_datasource.dart';
import 'package:budget_book/features/report/domain/entities/weekly_report.dart';
import 'package:budget_book/features/report/domain/entities/monthly_report.dart';
import 'package:budget_book/features/report/domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportRemoteDataSource remoteDataSource;

  ReportRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, WeeklyReport>> getWeeklyReport(
      int year, int month, int week) async {
    try {
      final result =
          await remoteDataSource.getWeeklyReport(year, month, week);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '주간 리포트를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('주간 리포트를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, MonthlyReport>> getMonthlyReport(
      int year, int month) async {
    try {
      final result = await remoteDataSource.getMonthlyReport(year, month);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '월간 리포트를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('월간 리포트를 불러오지 못했습니다'));
    }
  }

}
