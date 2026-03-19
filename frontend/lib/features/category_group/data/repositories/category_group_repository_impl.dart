import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/category_group/data/datasources/category_group_remote_datasource.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';
import 'package:budget_book/features/category_group/domain/repositories/category_group_repository.dart';

class CategoryGroupRepositoryImpl implements CategoryGroupRepository {
  final CategoryGroupRemoteDataSource remoteDataSource;

  CategoryGroupRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<CategoryGroup>>> getCategoryGroups() async {
    try {
      final result = await remoteDataSource.getCategoryGroups();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to load category groups'));
    } catch (e) {
      return const Left(ServerFailure('Failed to load category groups'));
    }
  }

  @override
  Future<Either<Failure, CategoryGroup>> createCategoryGroup({
    required String name,
    String? icon,
    String? color,
    String? budgetType,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (budgetType != null) 'budgetType': budgetType,
      };
      final result = await remoteDataSource.createCategoryGroup(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to create category group'));
    } catch (e) {
      return const Left(ServerFailure('Failed to create category group'));
    }
  }

  @override
  Future<Either<Failure, CategoryGroup>> updateCategoryGroup({
    required String id,
    String? name,
    String? icon,
    String? color,
    String? budgetType,
    int? displayOrder,
  }) async {
    try {
      final data = <String, dynamic>{
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (budgetType != null) 'budgetType': budgetType,
        if (displayOrder != null) 'displayOrder': displayOrder,
      };
      final result = await remoteDataSource.updateCategoryGroup(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to update category group'));
    } catch (e) {
      return const Left(ServerFailure('Failed to update category group'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategoryGroup(String id) async {
    try {
      await remoteDataSource.deleteCategoryGroup(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to delete category group'));
    } catch (e) {
      return const Left(ServerFailure('Failed to delete category group'));
    }
  }

  @override
  Future<Either<Failure, void>> reorderGroups(List<String> orderedIds) async {
    try {
      await remoteDataSource.reorderGroups(orderedIds);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to reorder category groups'));
    } catch (e) {
      return const Left(ServerFailure('Failed to reorder category groups'));
    }
  }
}
