import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/reconciliation/data/datasources/reconciliation_remote_datasource.dart';
import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';
import 'package:budget_book/features/reconciliation/domain/repositories/reconciliation_repository.dart';

class ReconciliationRepositoryImpl implements ReconciliationRepository {
  final ReconciliationRemoteDataSource remoteDataSource;

  ReconciliationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Reconciliation>>> getReconciliations({
    required int year,
    required int month,
  }) async {
    try {
      final result =
          await remoteDataSource.getReconciliations(year: year, month: month);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '정산 내역을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('정산 내역을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, ReconciliationDetail>> getReconciliation(
      String id) async {
    try {
      return Right(await remoteDataSource.getReconciliation(id));
    } on DioException catch (e) {
      return Left(mapDioError(e, '정산 상세를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('정산 상세를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, ReconciliationDetail>> createReconciliation({
    required String yearMonth,
    String? label,
    List<String> transactionIds = const [],
    List<String> transferIds = const [],
  }) async {
    try {
      final result = await remoteDataSource.createReconciliation(
        yearMonth: yearMonth,
        label: label,
        transactionIds: transactionIds,
        transferIds: transferIds,
      );
      return Right(result);
    } on DioException catch (e) {
      // 409 ALREADY_RECONCILED 는 파트너가 먼저 정산한 경우 — 메시지를 그대로 노출한다.
      return Left(mapDioError(e, '정산을 저장하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('정산을 저장하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, ReconciliationDetail>> updateReconciliation({
    required String id,
    String? label,
    List<String> addTransactionIds = const [],
    List<String> addTransferIds = const [],
    List<String> removeItemIds = const [],
  }) async {
    try {
      final result = await remoteDataSource.updateReconciliation(
        id: id,
        label: label,
        addTransactionIds: addTransactionIds,
        addTransferIds: addTransferIds,
        removeItemIds: removeItemIds,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '정산을 수정하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('정산을 수정하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteReconciliation(String id) async {
    try {
      await remoteDataSource.deleteReconciliation(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, '정산을 취소하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('정산을 취소하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, ReconciliationSummary>> getSummary({
    required int year,
    required int month,
  }) async {
    try {
      return Right(await remoteDataSource.getSummary(year: year, month: month));
    } on DioException catch (e) {
      return Left(mapDioError(e, '정산 요약을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('정산 요약을 불러오지 못했습니다'));
    }
  }
}
