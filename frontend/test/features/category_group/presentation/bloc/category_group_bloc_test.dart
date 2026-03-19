import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';
import 'package:budget_book/features/category_group/domain/repositories/category_group_repository.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/core/error/failure.dart';

class MockCategoryGroupRepository extends Mock
    implements CategoryGroupRepository {
  @override
  Future<Either<Failure, List<CategoryGroup>>> getCategoryGroups() =>
      super.noSuchMethod(
        Invocation.method(#getCategoryGroups, []),
        returnValue: Future.value(
          const Right<Failure, List<CategoryGroup>>([]),
        ),
      ) as Future<Either<Failure, List<CategoryGroup>>>;

  @override
  Future<Either<Failure, CategoryGroup>> createCategoryGroup({
    required String name,
    String? icon,
    String? color,
    String? budgetType,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createCategoryGroup, [], {
          #name: name,
          #icon: icon,
          #color: color,
          #budgetType: budgetType,
        }),
        returnValue: Future.value(
          Right<Failure, CategoryGroup>(CategoryGroup(
            id: '',
            name: '',
            budgetType: 'NONE',
            displayOrder: 0,
            isDefault: false,
            categories: const [],
            createdAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, CategoryGroup>>;

  @override
  Future<Either<Failure, CategoryGroup>> updateCategoryGroup({
    required String id,
    String? name,
    String? icon,
    String? color,
    String? budgetType,
    int? displayOrder,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateCategoryGroup, [], {
          #id: id,
          #name: name,
          #icon: icon,
          #color: color,
          #budgetType: budgetType,
          #displayOrder: displayOrder,
        }),
        returnValue: Future.value(
          Right<Failure, CategoryGroup>(CategoryGroup(
            id: '',
            name: '',
            budgetType: 'NONE',
            displayOrder: 0,
            isDefault: false,
            categories: const [],
            createdAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, CategoryGroup>>;

  @override
  Future<Either<Failure, void>> deleteCategoryGroup(String id) =>
      super.noSuchMethod(
        Invocation.method(#deleteCategoryGroup, [id]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, void>> reorderGroups(List<String> orderedIds) =>
      super.noSuchMethod(
        Invocation.method(#reorderGroups, [orderedIds]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;
}

void main() {
  late CategoryGroupBloc bloc;
  late MockCategoryGroupRepository mockRepository;

  final tCategory1 = Category(
    id: 'cat-1',
    name: '식비',
    type: 'EXPENSE',
    icon: 'restaurant',
    color: '#FF5733',
    isDefault: true,
    displayOrder: 1,
    groupId: 'group-1',
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tCategory2 = Category(
    id: 'cat-2',
    name: '교통비',
    type: 'EXPENSE',
    icon: 'directions_bus',
    color: '#2196F3',
    isDefault: true,
    displayOrder: 2,
    groupId: 'group-1',
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tGroup1 = CategoryGroup(
    id: 'group-1',
    name: '생활비',
    icon: 'account_balance_wallet',
    color: '#4CAF50',
    budgetType: 'MONTHLY',
    displayOrder: 1,
    isDefault: true,
    categories: [tCategory1, tCategory2],
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tGroup2 = CategoryGroup(
    id: 'group-2',
    name: '고정비',
    icon: 'home',
    color: '#2196F3',
    budgetType: 'MONTHLY',
    displayOrder: 2,
    isDefault: false,
    categories: const [],
    createdAt: DateTime.parse('2024-01-15T12:00:00Z'),
  );

  final tGroups = [tGroup1, tGroup2];

  final tNewGroup = CategoryGroup(
    id: 'group-3',
    name: '저축',
    icon: 'savings',
    color: '#FFC107',
    budgetType: 'MONTHLY',
    displayOrder: 3,
    isDefault: false,
    categories: const [],
    createdAt: DateTime.parse('2024-02-01T12:00:00Z'),
  );

  setUp(() {
    mockRepository = MockCategoryGroupRepository();
    bloc = CategoryGroupBloc(categoryGroupRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('CategoryGroupBloc', () {
    test('initial state is CategoryGroupInitial', () {
      expect(bloc.state, const CategoryGroupInitial());
    });

    group('LoadCategoryGroups', () {
      blocTest<CategoryGroupBloc, CategoryGroupState>(
        'emits [CategoryGroupLoading, CategoryGroupLoaded] on success',
        build: () {
          when(mockRepository.getCategoryGroups())
              .thenAnswer((_) async => Right(tGroups));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadCategoryGroups()),
        expect: () => [
          const CategoryGroupLoading(),
          CategoryGroupLoaded(tGroups),
        ],
      );

      blocTest<CategoryGroupBloc, CategoryGroupState>(
        'emits [CategoryGroupLoading, CategoryGroupError] on failure',
        build: () {
          when(mockRepository.getCategoryGroups()).thenAnswer(
              (_) async => const Left(
                  ServerFailure('Failed to load category groups')));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadCategoryGroups()),
        expect: () => [
          const CategoryGroupLoading(),
          const CategoryGroupError('Failed to load category groups'),
        ],
      );
    });

    group('CreateCategoryGroup', () {
      blocTest<CategoryGroupBloc, CategoryGroupState>(
        'emits [CategoryGroupLoaded] with new group appended',
        build: () {
          when(mockRepository.createCategoryGroup(
            name: '저축',
            icon: 'savings',
            color: '#FFC107',
            budgetType: 'MONTHLY',
          )).thenAnswer((_) async => Right(tNewGroup));
          return bloc;
        },
        seed: () => CategoryGroupLoaded(tGroups),
        act: (bloc) => bloc.add(const CreateCategoryGroup(
          name: '저축',
          icon: 'savings',
          color: '#FFC107',
          budgetType: 'MONTHLY',
        )),
        expect: () => [
          CategoryGroupLoaded([...tGroups, tNewGroup]),
        ],
      );

      blocTest<CategoryGroupBloc, CategoryGroupState>(
        'emits [CategoryGroupLoaded with operationError] on failure',
        build: () {
          when(mockRepository.createCategoryGroup(
            name: '저축',
            icon: 'savings',
            color: '#FFC107',
            budgetType: 'MONTHLY',
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to create category group')));
          return bloc;
        },
        seed: () => CategoryGroupLoaded(tGroups),
        act: (bloc) => bloc.add(const CreateCategoryGroup(
          name: '저축',
          icon: 'savings',
          color: '#FFC107',
          budgetType: 'MONTHLY',
        )),
        expect: () => [
          CategoryGroupLoaded(tGroups,
              operationError: 'Failed to create category group'),
        ],
      );
    });

    group('UpdateCategoryGroup', () {
      final tUpdatedGroup = CategoryGroup(
        id: 'group-2',
        name: '고정 지출',
        icon: 'home',
        color: '#E91E63',
        budgetType: 'MONTHLY',
        displayOrder: 2,
        isDefault: false,
        categories: const [],
        createdAt: DateTime.parse('2024-01-15T12:00:00Z'),
      );

      blocTest<CategoryGroupBloc, CategoryGroupState>(
        'emits [CategoryGroupLoaded] with updated group in list',
        build: () {
          when(mockRepository.updateCategoryGroup(
            id: 'group-2',
            name: '고정 지출',
            icon: 'home',
            color: '#E91E63',
            budgetType: 'MONTHLY',
          )).thenAnswer((_) async => Right(tUpdatedGroup));
          return bloc;
        },
        seed: () => CategoryGroupLoaded(tGroups),
        act: (bloc) => bloc.add(const UpdateCategoryGroup(
          id: 'group-2',
          name: '고정 지출',
          icon: 'home',
          color: '#E91E63',
          budgetType: 'MONTHLY',
        )),
        expect: () => [
          CategoryGroupLoaded([tGroup1, tUpdatedGroup]),
        ],
      );

      blocTest<CategoryGroupBloc, CategoryGroupState>(
        'emits [CategoryGroupLoaded with operationError] on failure',
        build: () {
          when(mockRepository.updateCategoryGroup(
            id: 'group-2',
            name: '고정 지출',
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to update category group')));
          return bloc;
        },
        seed: () => CategoryGroupLoaded(tGroups),
        act: (bloc) => bloc.add(const UpdateCategoryGroup(
          id: 'group-2',
          name: '고정 지출',
        )),
        expect: () => [
          CategoryGroupLoaded(tGroups,
              operationError: 'Failed to update category group'),
        ],
      );
    });

    group('DeleteCategoryGroup', () {
      blocTest<CategoryGroupBloc, CategoryGroupState>(
        'emits [CategoryGroupLoaded] with group removed',
        build: () {
          when(mockRepository.deleteCategoryGroup('group-2'))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () => CategoryGroupLoaded(tGroups),
        act: (bloc) => bloc.add(const DeleteCategoryGroup('group-2')),
        expect: () => [
          CategoryGroupLoaded([tGroup1]),
        ],
      );

      blocTest<CategoryGroupBloc, CategoryGroupState>(
        'emits [CategoryGroupLoaded with operationError] on failure',
        build: () {
          when(mockRepository.deleteCategoryGroup('group-1')).thenAnswer(
              (_) async => const Left(
                  ServerFailure('Default group cannot be deleted')));
          return bloc;
        },
        seed: () => CategoryGroupLoaded(tGroups),
        act: (bloc) => bloc.add(const DeleteCategoryGroup('group-1')),
        expect: () => [
          CategoryGroupLoaded(tGroups,
              operationError: 'Default group cannot be deleted'),
        ],
      );
    });

    group('ReorderCategoryGroups', () {
      blocTest<CategoryGroupBloc, CategoryGroupState>(
        'emits [CategoryGroupLoaded] with reordered list on success',
        build: () {
          when(mockRepository.reorderGroups(['group-2', 'group-1']))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () => CategoryGroupLoaded(tGroups),
        act: (bloc) =>
            bloc.add(const ReorderCategoryGroups(['group-2', 'group-1'])),
        expect: () => [
          CategoryGroupLoaded([tGroup2, tGroup1]),
        ],
      );

      blocTest<CategoryGroupBloc, CategoryGroupState>(
        'emits optimistic reorder then rollback on failure',
        build: () {
          when(mockRepository.reorderGroups(['group-2', 'group-1']))
              .thenAnswer((_) async => const Left(
                  ServerFailure('Failed to reorder category groups')));
          return bloc;
        },
        seed: () => CategoryGroupLoaded(tGroups),
        act: (bloc) =>
            bloc.add(const ReorderCategoryGroups(['group-2', 'group-1'])),
        expect: () => [
          // Optimistic reorder
          CategoryGroupLoaded([tGroup2, tGroup1]),
          // Rollback with error
          CategoryGroupLoaded(tGroups,
              operationError: 'Failed to reorder category groups'),
        ],
      );
    });
  });
}
