import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/weekly_budget/data/datasources/weekly_settlement_remote_datasource.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_settlement.dart';
import 'package:budget_book/features/weekly_budget/domain/repositories/weekly_settlement_repository.dart';

class WeeklySettlementRepositoryImpl implements WeeklySettlementRepository {
  final WeeklySettlementRemoteDataSource remoteDataSource;

  WeeklySettlementRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, WeeklySettlementOverview>> getSettlements(
      int year, int month) async {
    try {
      final result = await remoteDataSource.getSettlements(year, month);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '정산 정보를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('정산 정보를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, void>> settle(
      List<String> budgetIds, int weekNumber) async {
    try {
      await remoteDataSource.settle(budgetIds, weekNumber);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, '정산 처리에 실패했습니다'));
    } catch (e) {
      return const Left(ServerFailure('정산 처리에 실패했습니다'));
    }
  }

  @override
  Future<Either<Failure, void>> unsettle(
      List<String> budgetIds, int weekNumber) async {
    try {
      await remoteDataSource.unsettle(budgetIds, weekNumber);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, '정산 취소에 실패했습니다'));
    } catch (e) {
      return const Left(ServerFailure('정산 취소에 실패했습니다'));
    }
  }
}
