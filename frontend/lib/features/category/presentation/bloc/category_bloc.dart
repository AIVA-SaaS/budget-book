import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/domain/repositories/category_repository.dart';
import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository categoryRepository;

  CategoryBloc({required this.categoryRepository})
      : super(const CategoryInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<CreateCategory>(_onCreateCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<DeleteCategory>(_onDeleteCategory);
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      emit(const CategoryLoading());
      final result = await categoryRepository.getCategories(type: event.type);
      result.fold(
        (failure) => emit(CategoryError(failure.message)),
        (categories) => emit(CategoryLoaded(categories)),
      );
    } catch (_) {
      emit(const CategoryError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onCreateCategory(
    CreateCategory event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      final currentCategories =
          state is CategoryLoaded ? (state as CategoryLoaded).categories : <Category>[];
      final result = await categoryRepository.createCategory(
        name: event.name,
        type: event.type,
        icon: event.icon,
        color: event.color,
        groupId: event.groupId,
      );
      result.fold(
        (failure) => emit(CategoryLoaded(currentCategories,
            operationError: failure.message)),
        (category) => emit(CategoryLoaded([...currentCategories, category])),
      );
    } catch (_) {
      if (state is CategoryLoaded) {
        emit(CategoryLoaded((state as CategoryLoaded).categories,
            operationError: '예기치 않은 오류가 발생했습니다'));
      } else {
        emit(const CategoryError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onUpdateCategory(
    UpdateCategory event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      final currentCategories =
          state is CategoryLoaded ? (state as CategoryLoaded).categories : <Category>[];
      final result = await categoryRepository.updateCategory(
        id: event.id,
        name: event.name,
        icon: event.icon,
        color: event.color,
        displayOrder: event.displayOrder,
        groupId: event.groupId,
      );
      result.fold(
        (failure) => emit(CategoryLoaded(currentCategories,
            operationError: failure.message)),
        (updated) {
          final updatedList = currentCategories
              .map((c) => c.id == updated.id ? updated : c)
              .toList();
          emit(CategoryLoaded(updatedList));
        },
      );
    } catch (_) {
      if (state is CategoryLoaded) {
        emit(CategoryLoaded((state as CategoryLoaded).categories,
            operationError: '예기치 않은 오류가 발생했습니다'));
      } else {
        emit(const CategoryError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onDeleteCategory(
    DeleteCategory event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      final currentCategories =
          state is CategoryLoaded ? (state as CategoryLoaded).categories : <Category>[];
      final result = await categoryRepository.deleteCategory(event.id);
      result.fold(
        (failure) => emit(CategoryLoaded(currentCategories,
            operationError: failure.message)),
        (_) {
          final updatedList =
              currentCategories.where((c) => c.id != event.id).toList();
          emit(CategoryLoaded(updatedList));
        },
      );
    } catch (_) {
      if (state is CategoryLoaded) {
        emit(CategoryLoaded((state as CategoryLoaded).categories,
            operationError: '예기치 않은 오류가 발생했습니다'));
      } else {
        emit(const CategoryError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }
}
