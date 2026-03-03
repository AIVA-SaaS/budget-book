import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
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
      return Left(_mapDioError(e, 'Failed to get couple info'));
    }
  }

  @override
  Future<Either<Failure, Invitation>> createInvitation() async {
    try {
      final result = await remoteDataSource.createInvitation();
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to create invitation'));
    }
  }

  @override
  Future<Either<Failure, Couple>> acceptInvitation(String code) async {
    try {
      final result = await remoteDataSource.acceptInvitation(code);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to accept invitation'));
    }
  }

  @override
  Future<Either<Failure, void>> dissolveCouple() async {
    try {
      await remoteDataSource.dissolveCouple();
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to dissolve couple'));
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
