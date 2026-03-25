import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/transfer/data/datasources/transfer_remote_datasource.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transfer/domain/repositories/transfer_repository.dart';

class TransferRepositoryImpl implements TransferRepository {
  final TransferRemoteDataSource remoteDataSource;

  TransferRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Transfer>>> getTransfers({
    required int year,
    required int month,
  }) async {
    try {
      final result = await remoteDataSource.getTransfers(
        year: year,
        month: month,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '이체 목록을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('이체 목록을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, Transfer>> getTransfer(String id) async {
    try {
      final result = await remoteDataSource.getTransfer(id);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '이체를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('이체를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, Transfer>> createTransfer({
    required String sourcePaymentMethodId,
    required String destinationPaymentMethodId,
    required int amount,
    String? description,
    required String transferDate,
    String? memo,
  }) async {
    try {
      final data = <String, dynamic>{
        'sourcePaymentMethodId': sourcePaymentMethodId,
        'destinationPaymentMethodId': destinationPaymentMethodId,
        'amount': amount,
        'transferDate': transferDate,
        if (description != null) 'description': description,
        if (memo != null) 'memo': memo,
      };
      final result = await remoteDataSource.createTransfer(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '이체를 생성하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('이체를 생성하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, Transfer>> updateTransfer({
    required String id,
    String? sourcePaymentMethodId,
    String? destinationPaymentMethodId,
    int? amount,
    String? description,
    bool clearDescription = false,
    String? transferDate,
    String? memo,
    bool clearMemo = false,
  }) async {
    try {
      final data = <String, dynamic>{
        if (sourcePaymentMethodId != null)
          'sourcePaymentMethodId': sourcePaymentMethodId,
        if (destinationPaymentMethodId != null)
          'destinationPaymentMethodId': destinationPaymentMethodId,
        if (amount != null) 'amount': amount,
        if (description != null)
          'description': description
        else if (clearDescription)
          'description': null,
        if (transferDate != null) 'transferDate': transferDate,
        if (memo != null)
          'memo': memo
        else if (clearMemo)
          'memo': null,
      };
      final result = await remoteDataSource.updateTransfer(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '이체를 수정하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('이체를 수정하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTransfer(String id) async {
    try {
      await remoteDataSource.deleteTransfer(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, '이체를 삭제하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('이체를 삭제하지 못했습니다'));
    }
  }
}
