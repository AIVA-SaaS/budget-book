import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/pocket/data/datasources/pocket_transfer_remote_datasource.dart';
import 'package:budget_book/features/pocket/domain/entities/pocket_transfer.dart';
import 'package:budget_book/features/pocket/domain/repositories/pocket_transfer_repository.dart';

class PocketTransferRepositoryImpl implements PocketTransferRepository {
  final PocketTransferRemoteDataSource remoteDataSource;

  PocketTransferRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<PocketTransfer>>> getPocketTransfers({
    String? fromPocketId,
    String? toPocketId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final result = await remoteDataSource.getPocketTransfers(
        fromPocketId: fromPocketId,
        toPocketId: toPocketId,
        startDate: startDate,
        endDate: endDate,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to load pocket transfers'));
    } catch (e) {
      return const Left(ServerFailure('Failed to load pocket transfers'));
    }
  }

  @override
  Future<Either<Failure, PocketTransfer>> createPocketTransfer({
    required String fromPocketId,
    required String toPocketId,
    required int amount,
    String? description,
    required String transferDate,
  }) async {
    try {
      final data = <String, dynamic>{
        'fromPocketId': fromPocketId,
        'toPocketId': toPocketId,
        'amount': amount,
        'transferDate': transferDate,
        if (description != null) 'description': description,
      };
      final result = await remoteDataSource.createPocketTransfer(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to create pocket transfer'));
    } catch (e) {
      return const Left(ServerFailure('Failed to create pocket transfer'));
    }
  }

}
