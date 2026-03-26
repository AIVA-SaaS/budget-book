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
  final String? groupId;
  final String visibility;

  const CreateCategory({
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.groupId,
    this.visibility = 'SHARED',
  });

  @override
  List<Object?> get props => [name, type, icon, color, groupId, visibility];
}

class UpdateCategory extends CategoryEvent {
  final String id;
  final String? name;
  final String? icon;
  final String? color;
  final int? displayOrder;
  final String? groupId;

  const UpdateCategory({
    required this.id,
    this.name,
    this.icon,
    this.color,
    this.displayOrder,
    this.groupId,
  });

  @override
  List<Object?> get props => [id, name, icon, color, displayOrder, groupId];
}

class DeleteCategory extends CategoryEvent {
  final String id;

  const DeleteCategory(this.id);

  @override
  List<Object?> get props => [id];
}
