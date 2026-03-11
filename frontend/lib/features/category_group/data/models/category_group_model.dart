import 'package:budget_book/features/category/data/models/category_model.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';

class CategoryGroupModel extends CategoryGroup {
  const CategoryGroupModel({
    required super.id,
    required super.name,
    super.icon,
    super.color,
    required super.budgetType,
    required super.displayOrder,
    required super.isDefault,
    required super.categories,
    required super.createdAt,
  });

  factory CategoryGroupModel.fromJson(Map<String, dynamic> json) {
    final categoriesJson = json['categories'] as List<dynamic>? ?? [];
    return CategoryGroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      budgetType: json['budgetType'] as String? ?? 'NONE',
      displayOrder: json['displayOrder'] as int? ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
      categories: categoriesJson
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
