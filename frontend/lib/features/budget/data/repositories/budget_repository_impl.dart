import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/budget/data/datasources/budget_remote_datasource.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/domain/repositories/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetRemoteDataSource remoteDataSource;

  BudgetRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Budget>> createBudget({
    String? categoryId,
    String? groupId,
    required String yearMonth,
    required int amount,
    String budgetPeriod = 'MONTHLY',
    int? weeklyAmount,
    String? pocketId,
    String periodType = 'MONTHLY',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = <String, dynamic>{
        'yearMonth': yearMonth,
        'amount': amount,
        'budgetPeriod': budgetPeriod,
        'periodType': periodType,
        if (categoryId != null) 'categoryId': categoryId,
        if (groupId != null) 'groupId': groupId,
        if (weeklyAmount != null) 'weeklyAmount': weeklyAmount,
        if (pocketId != null) 'pocketId': pocketId,
        if (startDate != null) 'startDate': startDate.toIso8601String().split('T')[0],
        if (endDate != null) 'endDate': endDate.toIso8601String().split('T')[0],
      };
      final result = await remoteDataSource.createBudget(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '예산을 생성하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('예산을 생성하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<Budget>>> getBudgets({
    required int year,
    required int month,
  }) async {
    try {
      final result =
          await remoteDataSource.getBudgets(year: year, month: month);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '예산을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('예산을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, Budget>> updateBudget({
    required String id,
    required int amount,
    String? budgetPeriod,
    int? weeklyAmount,
    String? pocketId,
    String? periodType,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? groupId,
    String? yearMonth,
    bool applyToFuture = false,
  }) async {
    try {
      final data = <String, dynamic>{
        'amount': amount,
        if (budgetPeriod != null) 'budgetPeriod': budgetPeriod,
        if (weeklyAmount != null) 'weeklyAmount': weeklyAmount,
        if (pocketId != null) 'pocketId': pocketId,
        if (periodType != null) 'periodType': periodType,
        if (startDate != null) 'startDate': startDate.toIso8601String().split('T')[0],
        if (endDate != null) 'endDate': endDate.toIso8601String().split('T')[0],
        if (categoryId != null) 'categoryId': categoryId,
        if (groupId != null) 'groupId': groupId,
        if (yearMonth != null) 'yearMonth': yearMonth,
        if (applyToFuture) 'applyToFuture': true,
      };
      final result = await remoteDataSource.updateBudget(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '예산을 수정하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('예산을 수정하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteBudget(
    String id, {
    bool applyToFuture = false,
  }) async {
    try {
      await remoteDataSource.deleteBudget(id, applyToFuture: applyToFuture);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, '예산을 삭제하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('예산을 삭제하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, BudgetSummary>> getBudgetSummary({
    required int year,
    required int month,
  }) async {
    try {
      final result =
          await remoteDataSource.getBudgetSummary(year: year, month: month);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '예산 요약을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('예산 요약을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<Budget>>> copyPreviousMonthBudgets({
    required int year,
    required int month,
  }) async {
    try {
      final result = await remoteDataSource.copyPreviousMonthBudgets(
        year: year,
        month: month,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '전월 예산 복사에 실패했습니다'));
    } catch (e) {
      return const Left(ServerFailure('전월 예산 복사에 실패했습니다'));
    }
  }

}
