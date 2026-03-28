import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/preference/data/datasources/preference_remote_datasource.dart';
import 'package:budget_book/features/preference/domain/entities/favorites.dart';
import 'package:budget_book/features/preference/domain/repositories/preference_repository.dart';

class PreferenceRepositoryImpl implements PreferenceRepository {
  final PreferenceRemoteDataSource remoteDataSource;

  PreferenceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Favorites>> getFavorites() async {
    try {
      final result = await remoteDataSource.getFavorites();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '즐겨찾기를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('즐겨찾기를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, Favorites>> updateFavorites({
    required List<String> categoryIds,
    required List<String> paymentMethodIds,
  }) async {
    try {
      final data = <String, dynamic>{
        'categoryIds': categoryIds,
        'paymentMethodIds': paymentMethodIds,
      };
      final result = await remoteDataSource.updateFavorites(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '즐겨찾기를 저장하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('즐겨찾기를 저장하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, Favorites>> toggleFavorite({
    required String type,
    required String itemId,
  }) async {
    try {
      final data = <String, dynamic>{
        'type': type,
        'itemId': itemId,
      };
      final result = await remoteDataSource.toggleFavorite(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '즐겨찾기를 변경하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('즐겨찾기를 변경하지 못했습니다'));
    }
  }
}
