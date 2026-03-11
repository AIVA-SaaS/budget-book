import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';

abstract class CategoryGroupRepository {
  Future<Either<Failure, List<CategoryGroup>>> getCategoryGroups();
  Future<Either<Failure, CategoryGroup>> createCategoryGroup({
    required String name,
    String? icon,
    String? color,
    String? budgetType,
  });
  Future<Either<Failure, CategoryGroup>> updateCategoryGroup({
    required String id,
    String? name,
    String? icon,
    String? color,
    String? budgetType,
    int? displayOrder,
  });
  Future<Either<Failure, void>> deleteCategoryGroup(String id);
}
