import 'package:equatable/equatable.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';

sealed class CategoryState extends Equatable {
  const CategoryState();

  @override
  List<Object?> get props => [];
}

class CategoryInitial extends CategoryState {
  const CategoryInitial();
}

class CategoryLoading extends CategoryState {
  const CategoryLoading();
}

class CategoryLoaded extends CategoryState {
  final List<Category> categories;
  final String? operationError;

  const CategoryLoaded(this.categories, {this.operationError});

  List<Category> get incomeCategories =>
      categories.where((c) => c.isIncome).toList();

  List<Category> get expenseCategories =>
      categories.where((c) => c.isExpense).toList();

  @override
  List<Object?> get props => [categories, operationError];
}

class CategoryError extends CategoryState {
  final String message;

  const CategoryError(this.message);

  @override
  List<Object?> get props => [message];
}
