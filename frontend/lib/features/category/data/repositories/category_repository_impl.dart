import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/services/cache_service.dart';
import 'package:budget_book/features/category/data/datasources/category_remote_datasource.dart';
import 'package:budget_book/features/category/data/models/category_model.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDataSource remoteDataSource;
  final CacheService? cacheService;

  static const String _cacheKey = 'cached_categories';

  CategoryRepositoryImpl({
    required this.remoteDataSource,
    this.cacheService,
  });

  @override
  Future<Either<Failure, List<Category>>> getCategories({String? type}) async {
    try {
      final result = await remoteDataSource.getCategories(type: type);
      // Cache the result on success (only cache full list without type filter)
      if (type == null && cacheService != null) {
        try {
          final jsonList = result.map((c) => _categoryToJson(c)).toList();
          await cacheService!.cacheData(_cacheKey, jsonEncode(jsonList));
        } catch (_) {
          // Caching failure should not affect the main flow
        }
      }
      return Right(result);
    } on DioException catch (e) {
      // On API failure, try to serve cached data
      if (cacheService != null) {
        final cached = await _getCachedCategories(type);
        if (cached != null) return Right(cached);
      }
      return Left(_mapDioError(e, 'Failed to load categories'));
    }
  }

  Future<List<Category>?> _getCachedCategories(String? type) async {
    try {
      final jsonString = await cacheService!.getCachedData(_cacheKey);
      if (jsonString == null) return null;
      final list = jsonDecode(jsonString) as List<dynamic>;
      final categories = list
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (type != null) {
        return categories.where((c) => c.type == type).toList();
      }
      return categories;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _categoryToJson(CategoryModel model) {
    return {
      'id': model.id,
      'name': model.name,
      'type': model.type,
      'icon': model.icon,
      'color': model.color,
      'isDefault': model.isDefault,
      'displayOrder': model.displayOrder,
      'groupId': model.groupId,
      'createdAt': model.createdAt.toIso8601String(),
    };
  }

  @override
  Future<Either<Failure, Category>> createCategory({
    required String name,
    required String type,
    String? icon,
    String? color,
    String? groupId,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'type': type,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (groupId != null) 'groupId': groupId,
      };
      final result = await remoteDataSource.createCategory(data);
      // Invalidate cache after mutation
      await cacheService?.removeCachedData(_cacheKey);
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
    String? groupId,
  }) async {
    try {
      final data = <String, dynamic>{
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (displayOrder != null) 'displayOrder': displayOrder,
        if (groupId != null) 'groupId': groupId,
      };
      final result = await remoteDataSource.updateCategory(id, data);
      await cacheService?.removeCachedData(_cacheKey);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to update category'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async {
    try {
      await remoteDataSource.deleteCategory(id);
      await cacheService?.removeCachedData(_cacheKey);
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
