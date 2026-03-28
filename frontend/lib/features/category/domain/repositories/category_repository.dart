import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';

abstract class CategoryRepository {
  Future<Either<Failure, List<Category>>> getCategories({String? type});
  Future<Either<Failure, Category>> createCategory({
    required String name,
    required String type,
    String? icon,
    String? color,
    String? groupId,
    String visibility = 'SHARED',
  });
  Future<Either<Failure, Category>> updateCategory({
    required String id,
    String? name,
    String? icon,
    String? color,
    int? displayOrder,
    String? groupId,
  });
  Future<Either<Failure, void>> deleteCategory(String id);
  Future<Either<Failure, void>> reorderCategories(List<String> orderedIds);
}
