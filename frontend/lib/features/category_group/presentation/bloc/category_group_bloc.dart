import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';
import 'package:budget_book/features/category_group/domain/repositories/category_group_repository.dart';
import 'category_group_event.dart';
import 'category_group_state.dart';

class CategoryGroupBloc
    extends Bloc<CategoryGroupEvent, CategoryGroupState> {
  final CategoryGroupRepository categoryGroupRepository;

  CategoryGroupBloc({required this.categoryGroupRepository})
      : super(const CategoryGroupInitial()) {
    on<LoadCategoryGroups>(_onLoadCategoryGroups);
    on<CreateCategoryGroup>(_onCreateCategoryGroup);
    on<UpdateCategoryGroup>(_onUpdateCategoryGroup);
    on<DeleteCategoryGroup>(_onDeleteCategoryGroup);
    on<ReorderCategoryGroups>(_onReorderCategoryGroups);
  }

  Future<void> _onLoadCategoryGroups(
    LoadCategoryGroups event,
    Emitter<CategoryGroupState> emit,
  ) async {
    try {
      emit(const CategoryGroupLoading());
      final result = await categoryGroupRepository.getCategoryGroups();
      result.fold(
        (failure) => emit(CategoryGroupError(failure.message)),
        (groups) => emit(CategoryGroupLoaded(groups)),
      );
    } catch (e) {
      emit(const CategoryGroupError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onCreateCategoryGroup(
    CreateCategoryGroup event,
    Emitter<CategoryGroupState> emit,
  ) async {
    final currentGroups = state is CategoryGroupLoaded
        ? (state as CategoryGroupLoaded).groups
        : <CategoryGroup>[];

    try {
      final result = await categoryGroupRepository.createCategoryGroup(
        name: event.name,
        icon: event.icon,
        color: event.color,
        budgetType: event.budgetType,
        visibility: event.visibility,
      );
      result.fold(
        (failure) => emit(CategoryGroupLoaded(currentGroups,
            operationError: failure.message)),
        (group) => emit(CategoryGroupLoaded([...currentGroups, group])),
      );
    } catch (e) {
      emit(CategoryGroupLoaded(currentGroups,
          operationError: '예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onUpdateCategoryGroup(
    UpdateCategoryGroup event,
    Emitter<CategoryGroupState> emit,
  ) async {
    final currentGroups = state is CategoryGroupLoaded
        ? (state as CategoryGroupLoaded).groups
        : <CategoryGroup>[];

    try {
      final result = await categoryGroupRepository.updateCategoryGroup(
        id: event.id,
        name: event.name,
        icon: event.icon,
        color: event.color,
        budgetType: event.budgetType,
        displayOrder: event.displayOrder,
      );
      result.fold(
        (failure) => emit(CategoryGroupLoaded(currentGroups,
            operationError: failure.message)),
        (updated) {
          final updatedList = currentGroups
              .map((g) => g.id == updated.id ? updated : g)
              .toList();
          emit(CategoryGroupLoaded(updatedList));
        },
      );
    } catch (e) {
      emit(CategoryGroupLoaded(currentGroups,
          operationError: '예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onDeleteCategoryGroup(
    DeleteCategoryGroup event,
    Emitter<CategoryGroupState> emit,
  ) async {
    final currentGroups = state is CategoryGroupLoaded
        ? (state as CategoryGroupLoaded).groups
        : <CategoryGroup>[];

    try {
      final result =
          await categoryGroupRepository.deleteCategoryGroup(event.id);
      result.fold(
        (failure) => emit(CategoryGroupLoaded(currentGroups,
            operationError: failure.message)),
        (_) {
          final updatedList =
              currentGroups.where((g) => g.id != event.id).toList();
          emit(CategoryGroupLoaded(updatedList));
        },
      );
    } catch (e) {
      emit(CategoryGroupLoaded(currentGroups,
          operationError: '예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onReorderCategoryGroups(
    ReorderCategoryGroups event,
    Emitter<CategoryGroupState> emit,
  ) async {
    final currentGroups = state is CategoryGroupLoaded
        ? (state as CategoryGroupLoaded).groups
        : <CategoryGroup>[];

    // Optimistic update: reorder locally first
    final reordered = <CategoryGroup>[];
    for (final id in event.orderedIds) {
      final group = currentGroups.firstWhere(
        (g) => g.id == id,
        orElse: () => currentGroups.first,
      );
      reordered.add(group);
    }
    emit(CategoryGroupLoaded(reordered));

    try {
      final result =
          await categoryGroupRepository.reorderGroups(event.orderedIds);
      result.fold(
        (failure) {
          // Rollback on failure
          emit(CategoryGroupLoaded(currentGroups,
              operationError: failure.message));
        },
        (_) {
          // Already showing reordered state
        },
      );
    } catch (e) {
      // Rollback on unexpected error
      emit(CategoryGroupLoaded(currentGroups,
          operationError: '예기치 않은 오류가 발생했습니다'));
    }
  }
}
