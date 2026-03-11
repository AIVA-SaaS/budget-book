import 'package:equatable/equatable.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';

sealed class CategoryGroupState extends Equatable {
  const CategoryGroupState();

  @override
  List<Object?> get props => [];
}

class CategoryGroupInitial extends CategoryGroupState {
  const CategoryGroupInitial();
}

class CategoryGroupLoading extends CategoryGroupState {
  const CategoryGroupLoading();
}

class CategoryGroupLoaded extends CategoryGroupState {
  final List<CategoryGroup> groups;
  final String? operationError;

  const CategoryGroupLoaded(this.groups, {this.operationError});

  @override
  List<Object?> get props => [groups, operationError];
}

class CategoryGroupError extends CategoryGroupState {
  final String message;

  const CategoryGroupError(this.message);

  @override
  List<Object?> get props => [message];
}
