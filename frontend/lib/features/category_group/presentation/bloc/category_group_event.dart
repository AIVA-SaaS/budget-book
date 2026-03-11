import 'package:equatable/equatable.dart';

sealed class CategoryGroupEvent extends Equatable {
  const CategoryGroupEvent();

  @override
  List<Object?> get props => [];
}

class LoadCategoryGroups extends CategoryGroupEvent {
  const LoadCategoryGroups();
}

class CreateCategoryGroup extends CategoryGroupEvent {
  final String name;
  final String? icon;
  final String? color;
  final String? budgetType;

  const CreateCategoryGroup({
    required this.name,
    this.icon,
    this.color,
    this.budgetType,
  });

  @override
  List<Object?> get props => [name, icon, color, budgetType];
}

class UpdateCategoryGroup extends CategoryGroupEvent {
  final String id;
  final String? name;
  final String? icon;
  final String? color;
  final String? budgetType;
  final int? displayOrder;

  const UpdateCategoryGroup({
    required this.id,
    this.name,
    this.icon,
    this.color,
    this.budgetType,
    this.displayOrder,
  });

  @override
  List<Object?> get props => [id, name, icon, color, budgetType, displayOrder];
}

class DeleteCategoryGroup extends CategoryGroupEvent {
  final String id;

  const DeleteCategoryGroup(this.id);

  @override
  List<Object?> get props => [id];
}
