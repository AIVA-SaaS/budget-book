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
    } catch (e) {
      return const Left(ServerFailure('Token refresh failed'));
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
    } catch (e) {
      return const Left(ServerFailure('Failed to get user'));
    }
  }

  @override
  Future<Either<Failure, User>> updateProfile({
    String? nickname,
    String? profileImageUrl,
    bool clearProfileImage = false,
  }) async {
    try {
      final result = await remoteDataSource.updateProfile(
        nickname: nickname,
        profileImageUrl: profileImageUrl,
        clearProfileImage: clearProfileImage,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['error']?['message'] as String? ??
              'Failed to update profile',
        ),
      );
    } catch (e) {
      return const Left(ServerFailure('Failed to update profile'));
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
    } catch (e) {
      return const Left(ServerFailure('Logout failed'));
    }
  }

  @override
  Future<Either<Failure, User>> uploadProfileImage(
      List<int> imageBytes, String fileName) async {
    try {
      final result =
          await remoteDataSource.uploadProfileImage(imageBytes, fileName);
      return Right(result);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['error']?['message'] as String? ??
              'Failed to upload profile image',
        ),
      );
    } catch (e) {
      return const Left(ServerFailure('Failed to upload profile image'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProfileImage() async {
    try {
      await remoteDataSource.deleteProfileImage();
      return const Right(null);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['error']?['message'] as String? ??
              'Failed to delete profile image',
        ),
      );
    } catch (e) {
      return const Left(ServerFailure('Failed to delete profile image'));
    }
  }
}
