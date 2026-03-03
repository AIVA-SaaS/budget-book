import 'package:budget_book/features/category/domain/entities/category.dart';

class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.name,
    required super.type,
    super.icon,
    super.color,
    required super.isDefault,
    required super.displayOrder,
    required super.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isDefault: json['isDefault'] as bool,
      displayOrder: json['displayOrder'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
