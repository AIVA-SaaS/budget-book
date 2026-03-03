import 'package:equatable/equatable.dart';

sealed class CategoryEvent extends Equatable {
  const CategoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadCategories extends CategoryEvent {
  final String? type;

  const LoadCategories({this.type});

  @override
  List<Object?> get props => [type];
}

class CreateCategory extends CategoryEvent {
  final String name;
  final String type;
  final String? icon;
  final String? color;

  const CreateCategory({
    required this.name,
    required this.type,
    this.icon,
    this.color,
  });

  @override
  List<Object?> get props => [name, type, icon, color];
}

class UpdateCategory extends CategoryEvent {
  final String id;
  final String? name;
  final String? icon;
  final String? color;
  final int? displayOrder;

  const UpdateCategory({
    required this.id,
    this.name,
    this.icon,
    this.color,
    this.displayOrder,
  });

  @override
  List<Object?> get props => [id, name, icon, color, displayOrder];
}

class DeleteCategory extends CategoryEvent {
  final String id;

  const DeleteCategory(this.id);

  @override
  List<Object?> get props => [id];
}
