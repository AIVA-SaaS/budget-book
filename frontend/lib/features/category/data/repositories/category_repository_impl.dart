import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/category/data/datasources/category_remote_datasource.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDataSource remoteDataSource;

  CategoryRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Category>>> getCategories({String? type}) async {
    try {
      final result = await remoteDataSource.getCategories(type: type);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to load categories'));
    }
  }

  @override
  Future<Either<Failure, Category>> createCategory({
    required String name,
    required String type,
    String? icon,
    String? color,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'type': type,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
      };
      final result = await remoteDataSource.createCategory(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to create category'));
    }
  }

  @override
  Future<Either<Failure, Category>> updateCategory({
    required String id,
    String? name,
    String? icon,
    String? color,
    int? displayOrder,
  }) async {
    try {
      final data = <String, dynamic>{
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (displayOrder != null) 'displayOrder': displayOrder,
      };
      final result = await remoteDataSource.updateCategory(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to update category'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async {
    try {
      await remoteDataSource.deleteCategory(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to delete category'));
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
