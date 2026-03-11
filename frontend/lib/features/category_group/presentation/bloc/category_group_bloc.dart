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
  }

  Future<void> _onLoadCategoryGroups(
    LoadCategoryGroups event,
    Emitter<CategoryGroupState> emit,
  ) async {
    emit(const CategoryGroupLoading());
    final result = await categoryGroupRepository.getCategoryGroups();
    result.fold(
      (failure) => emit(CategoryGroupError(failure.message)),
      (groups) => emit(CategoryGroupLoaded(groups)),
    );
  }

  Future<void> _onCreateCategoryGroup(
    CreateCategoryGroup event,
    Emitter<CategoryGroupState> emit,
  ) async {
    final currentGroups = state is CategoryGroupLoaded
        ? (state as CategoryGroupLoaded).groups
        : <CategoryGroup>[];
    final result = await categoryGroupRepository.createCategoryGroup(
      name: event.name,
      icon: event.icon,
      color: event.color,
      budgetType: event.budgetType,
    );
    result.fold(
      (failure) => emit(CategoryGroupLoaded(currentGroups,
          operationError: failure.message)),
      (group) => emit(CategoryGroupLoaded([...currentGroups, group])),
    );
  }

  Future<void> _onUpdateCategoryGroup(
    UpdateCategoryGroup event,
    Emitter<CategoryGroupState> emit,
  ) async {
    final currentGroups = state is CategoryGroupLoaded
        ? (state as CategoryGroupLoaded).groups
        : <CategoryGroup>[];
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
  }

  Future<void> _onDeleteCategoryGroup(
    DeleteCategoryGroup event,
    Emitter<CategoryGroupState> emit,
  ) async {
    final currentGroups = state is CategoryGroupLoaded
        ? (state as CategoryGroupLoaded).groups
        : <CategoryGroup>[];
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
  }
}
