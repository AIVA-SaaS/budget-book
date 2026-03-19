import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/couple/data/datasources/couple_remote_datasource.dart';
import 'package:budget_book/features/couple/domain/entities/couple.dart';
import 'package:budget_book/features/couple/domain/entities/invitation.dart';
import 'package:budget_book/features/couple/domain/repositories/couple_repository.dart';

class CoupleRepositoryImpl implements CoupleRepository {
  final CoupleRemoteDataSource remoteDataSource;

  CoupleRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Couple>> getMyCouple() async {
    try {
      final result = await remoteDataSource.getMyCouple();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to get couple info'));
    } catch (e) {
      return const Left(ServerFailure('Failed to get couple info'));
    }
  }

  @override
  Future<Either<Failure, Invitation>> createInvitation() async {
    try {
      final result = await remoteDataSource.createInvitation();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to create invitation'));
    } catch (e) {
      return const Left(ServerFailure('Failed to create invitation'));
    }
  }

  @override
  Future<Either<Failure, Couple>> acceptInvitation(String code) async {
    try {
      final result = await remoteDataSource.acceptInvitation(code);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to accept invitation'));
    } catch (e) {
      return const Left(ServerFailure('Failed to accept invitation'));
    }
  }

  @override
  Future<Either<Failure, void>> dissolveCouple() async {
    try {
      await remoteDataSource.dissolveCouple();
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to dissolve couple'));
    } catch (e) {
      return const Left(ServerFailure('Failed to dissolve couple'));
    }
  }

  @override
  Future<Either<Failure, Invitation>> getMyInvitation() async {
    try {
      final result = await remoteDataSource.getMyInvitation();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to get invitation status'));
    } catch (e) {
      return const Left(ServerFailure('Failed to get invitation status'));
    }
  }
}
