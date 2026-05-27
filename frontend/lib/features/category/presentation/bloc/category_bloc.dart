import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/domain/repositories/category_repository.dart';
import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository categoryRepository;

  /// Invoked after a successful category mutation (create/update/delete) so
  /// dependent views (statistics breakdown, transaction list, dashboard) can
  /// refresh. Wired in DI to [SyncEventHandler.refreshCategoryDependents];
  /// left null in tests.
  final void Function()? onChanged;

  CategoryBloc({required this.categoryRepository, this.onChanged})
      : super(const CategoryInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<CreateCategory>(_onCreateCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<DeleteCategory>(_onDeleteCategory);
    on<ReorderCategories>(_onReorderCategories);
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      // 회차 12 follow-up (2026-05-04) — race 회귀 fix.
      // 이미 Loaded 상태에서 reload 시 Loading 으로 잠시 transition →
      // BlocBuilder 가 SizedBox.shrink / empty UI → 깜박임. 기존 data 보존.
      final currentLoaded =
          state is CategoryLoaded ? state as CategoryLoaded : null;
      if (currentLoaded == null) {
        emit(const CategoryLoading());
      }
      final result = await categoryRepository.getCategories(type: event.type);
      result.fold(
        (failure) {
          if (currentLoaded != null) {
            emit(CategoryLoaded(currentLoaded.categories,
                operationError: failure.message));
          } else {
            emit(CategoryError(failure.message));
          }
        },
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
        visibility: event.visibility,
      );
      result.fold(
        (failure) => emit(CategoryLoaded(currentCategories,
            operationError: failure.message)),
        (category) {
          emit(CategoryLoaded([...currentCategories, category]));
          onChanged?.call();
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
          onChanged?.call();
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

  Future<void> _onReorderCategories(
    ReorderCategories event,
    Emitter<CategoryState> emit,
  ) async {
    final currentCategories =
        state is CategoryLoaded ? (state as CategoryLoaded).categories : <Category>[];
    try {
      final result = await categoryRepository.reorderCategories(event.orderedIds);
      result.fold(
        (failure) => emit(CategoryLoaded(currentCategories,
            operationError: failure.message)),
        (_) {
          // Reorder locally to reflect changes immediately
          final reordered = <Category>[];
          for (final id in event.orderedIds) {
            final cat = currentCategories.where((c) => c.id == id).firstOrNull;
            if (cat != null) reordered.add(cat);
          }
          // Add any categories not in the reorder list
          for (final cat in currentCategories) {
            if (!event.orderedIds.contains(cat.id)) reordered.add(cat);
          }
          emit(CategoryLoaded(reordered));
        },
      );
    } catch (_) {
      emit(CategoryLoaded(currentCategories,
          operationError: '예기치 않은 오류가 발생했습니다'));
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
          onChanged?.call();
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
