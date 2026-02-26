import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:budget_book/features/auth/domain/entities/user.dart';
import 'package:budget_book/features/auth/domain/entities/auth_token.dart';
import 'package:budget_book/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, AuthToken>> refreshToken(String refreshToken) async {
    try {
      final result = await remoteDataSource.refreshToken(refreshToken);
      return Right(result);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['error']?['message'] as String? ??
              'Token refresh failed',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      final result = await remoteDataSource.getCurrentUser();
      return Right(result);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['error']?['message'] as String? ??
              'Failed to get user',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> logout(String refreshToken) async {
    try {
      await remoteDataSource.logout(refreshToken);
      return const Right(null);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['error']?['message'] as String? ??
              'Logout failed',
        ),
      );
    }
  }
}
