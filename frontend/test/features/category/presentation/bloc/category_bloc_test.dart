import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category/domain/repositories/category_repository.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/core/error/failure.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {
  @override
  Future<Either<Failure, List<Category>>> getCategories({String? type}) =>
      super.noSuchMethod(
        Invocation.method(#getCategories, [], {#type: type}),
        returnValue: Future.value(
          const Right<Failure, List<Category>>([]),
        ),
      ) as Future<Either<Failure, List<Category>>>;

  @override
  Future<Either<Failure, Category>> createCategory({
    required String name,
    required String type,
    String? icon,
    String? color,
    String? groupId,
    String visibility = 'SHARED',
  }) =>
      super.noSuchMethod(
        Invocation.method(#createCategory, [],
            {#name: name, #type: type, #icon: icon, #color: color, #groupId: groupId, #visibility: visibility}),
        returnValue: Future.value(
          Right<Failure, Category>(Category(
            id: '',
            name: '',
            type: 'EXPENSE',
            isDefault: false,
            displayOrder: 0,
            createdAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, Category>>;

  @override
  Future<Either<Failure, Category>> updateCategory({
    required String id,
    String? name,
    String? icon,
    String? color,
    int? displayOrder,
    String? groupId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateCategory, [], {
          #id: id,
          #name: name,
          #icon: icon,
          #color: color,
          #displayOrder: displayOrder,
          #groupId: groupId,
        }),
        returnValue: Future.value(
          Right<Failure, Category>(Category(
            id: '',
            name: '',
            type: 'EXPENSE',
            isDefault: false,
            displayOrder: 0,
            createdAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, Category>>;

  @override
  Future<Either<Failure, void>> deleteCategory(String id) =>
      super.noSuchMethod(
        Invocation.method(#deleteCategory, [id]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, void>> reorderCategories(List<String> orderedIds) =>
      super.noSuchMethod(
        Invocation.method(#reorderCategories, [orderedIds]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;
}

void main() {
  late CategoryBloc categoryBloc;
  late MockCategoryRepository mockRepository;

  final tExpenseCategory = Category(
    id: 'cat-1',
    name: '식비',
    type: 'EXPENSE',
    icon: 'restaurant',
    color: '#FF5733',
    isDefault: true,
    displayOrder: 1,
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tIncomeCategory = Category(
    id: 'cat-2',
    name: '급여',
    type: 'INCOME',
    icon: 'payments',
    color: '#4CAF50',
    isDefault: true,
    displayOrder: 1,
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tNewCategory = Category(
    id: 'cat-3',
    name: '반려동물',
    type: 'EXPENSE',
    icon: 'pets',
    color: '#9C27B0',
    isDefault: false,
    displayOrder: 10,
    createdAt: DateTime.parse('2024-01-15T12:00:00Z'),
  );

  final tCategories = [tExpenseCategory, tIncomeCategory];

  setUp(() {
    mockRepository = MockCategoryRepository();
    categoryBloc = CategoryBloc(categoryRepository: mockRepository);
  });

  tearDown(() {
    categoryBloc.close();
  });

  group('CategoryBloc', () {
    test('initial state is CategoryInitial', () {
      expect(categoryBloc.state, const CategoryInitial());
    });

    group('LoadCategories', () {
      blocTest<CategoryBloc, CategoryState>(
        'emits [CategoryLoading, CategoryLoaded] on success',
        build: () {
          when(mockRepository.getCategories(type: null))
              .thenAnswer((_) async => Right(tCategories));
          return categoryBloc;
        },
        act: (bloc) => bloc.add(const LoadCategories()),
        expect: () => [
          const CategoryLoading(),
          CategoryLoaded(tCategories),
        ],
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [CategoryLoading, CategoryLoaded] with type filter',
        build: () {
          when(mockRepository.getCategories(type: 'EXPENSE'))
              .thenAnswer((_) async => Right([tExpenseCategory]));
          return categoryBloc;
        },
        act: (bloc) => bloc.add(const LoadCategories(type: 'EXPENSE')),
        expect: () => [
          const CategoryLoading(),
          CategoryLoaded([tExpenseCategory]),
        ],
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [CategoryLoading, CategoryError] on failure',
        build: () {
          when(mockRepository.getCategories(type: null)).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('Failed to load categories')));
          return categoryBloc;
        },
        act: (bloc) => bloc.add(const LoadCategories()),
        expect: () => [
          const CategoryLoading(),
          const CategoryError('Failed to load categories'),
        ],
      );
    });

    group('CreateCategory', () {
      blocTest<CategoryBloc, CategoryState>(
        'emits [CategoryLoaded] with new category appended (no loading)',
        build: () {
          when(mockRepository.createCategory(
            name: '반려동물',
            type: 'EXPENSE',
            icon: 'pets',
            color: '#9C27B0',
          )).thenAnswer((_) async => Right(tNewCategory));
          return categoryBloc;
        },
        seed: () => CategoryLoaded(tCategories),
        act: (bloc) => bloc.add(const CreateCategory(
          name: '반려동물',
          type: 'EXPENSE',
          icon: 'pets',
          color: '#9C27B0',
        )),
        expect: () => [
          CategoryLoaded([...tCategories, tNewCategory]),
        ],
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [CategoryLoaded with operationError] on failure, preserving list',
        build: () {
          when(mockRepository.createCategory(
            name: '반려동물',
            type: 'EXPENSE',
            icon: 'pets',
            color: '#9C27B0',
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to create category')));
          return categoryBloc;
        },
        seed: () => CategoryLoaded(tCategories),
        act: (bloc) => bloc.add(const CreateCategory(
          name: '반려동물',
          type: 'EXPENSE',
          icon: 'pets',
          color: '#9C27B0',
        )),
        expect: () => [
          CategoryLoaded(tCategories,
              operationError: 'Failed to create category'),
        ],
      );
    });

    group('UpdateCategory', () {
      final tUpdatedCategory = Category(
        id: 'cat-1',
        name: '식비/외식',
        type: 'EXPENSE',
        icon: 'restaurant_menu',
        color: '#E91E63',
        isDefault: true,
        displayOrder: 1,
        createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [CategoryLoaded] with updated category in list (no loading)',
        build: () {
          when(mockRepository.updateCategory(
            id: 'cat-1',
            name: '식비/외식',
            icon: 'restaurant_menu',
            color: '#E91E63',
          )).thenAnswer((_) async => Right(tUpdatedCategory));
          return categoryBloc;
        },
        seed: () => CategoryLoaded(tCategories),
        act: (bloc) => bloc.add(const UpdateCategory(
          id: 'cat-1',
          name: '식비/외식',
          icon: 'restaurant_menu',
          color: '#E91E63',
        )),
        expect: () => [
          CategoryLoaded([tUpdatedCategory, tIncomeCategory]),
        ],
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [CategoryLoaded with operationError] on failure, preserving list',
        build: () {
          when(mockRepository.updateCategory(
            id: 'cat-1',
            name: '식비/외식',
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to update category')));
          return categoryBloc;
        },
        seed: () => CategoryLoaded(tCategories),
        act: (bloc) => bloc.add(const UpdateCategory(
          id: 'cat-1',
          name: '식비/외식',
        )),
        expect: () => [
          CategoryLoaded(tCategories,
              operationError: 'Failed to update category'),
        ],
      );
    });

    group('DeleteCategory', () {
      blocTest<CategoryBloc, CategoryState>(
        'emits [CategoryLoaded] with category removed (no loading)',
        build: () {
          when(mockRepository.deleteCategory('cat-1'))
              .thenAnswer((_) async => const Right(null));
          return categoryBloc;
        },
        seed: () => CategoryLoaded(tCategories),
        act: (bloc) => bloc.add(const DeleteCategory('cat-1')),
        expect: () => [
          CategoryLoaded([tIncomeCategory]),
        ],
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [CategoryLoaded with operationError] when deleting default category',
        build: () {
          when(mockRepository.deleteCategory('cat-1')).thenAnswer((_) async =>
              const Left(
                  ServerFailure('Default categories cannot be deleted')));
          return categoryBloc;
        },
        seed: () => CategoryLoaded(tCategories),
        act: (bloc) => bloc.add(const DeleteCategory('cat-1')),
        expect: () => [
          CategoryLoaded(tCategories,
              operationError: 'Default categories cannot be deleted'),
        ],
      );
    });

    group('ReorderCategories', () {
      blocTest<CategoryBloc, CategoryState>(
        'emits [CategoryLoaded] with reordered categories on success',
        build: () {
          when(mockRepository.reorderCategories(['cat-2', 'cat-1']))
              .thenAnswer((_) async => const Right(null));
          return categoryBloc;
        },
        seed: () => CategoryLoaded(tCategories),
        act: (bloc) => bloc.add(const ReorderCategories(['cat-2', 'cat-1'])),
        expect: () => [
          CategoryLoaded([tIncomeCategory, tExpenseCategory]),
        ],
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [CategoryLoaded with operationError] on failure',
        build: () {
          when(mockRepository.reorderCategories(['cat-2', 'cat-1']))
              .thenAnswer((_) async =>
                  const Left(ServerFailure('Failed to reorder categories')));
          return categoryBloc;
        },
        seed: () => CategoryLoaded(tCategories),
        act: (bloc) => bloc.add(const ReorderCategories(['cat-2', 'cat-1'])),
        expect: () => [
          CategoryLoaded(tCategories,
              operationError: 'Failed to reorder categories'),
        ],
      );
    });

    // Regression: 카테고리 이름/그룹 수정이 통계에 반영 안 되던 문제.
    // 수정 성공 시 onChanged 가 호출되어야 의존 화면(통계/거래/대시보드)이 갱신됨.
    group('onChanged dependent-refresh callback', () {
      late int changedCount;

      final tUpdated = Category(
        id: 'cat-1',
        name: '부모님',
        type: 'EXPENSE',
        isDefault: false,
        displayOrder: 1,
        createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
      );

      blocTest<CategoryBloc, CategoryState>(
        'invokes onChanged after successful update',
        build: () {
          when(mockRepository.updateCategory(id: 'cat-1', name: '부모님'))
              .thenAnswer((_) async => Right(tUpdated));
          changedCount = 0;
          return CategoryBloc(
            categoryRepository: mockRepository,
            onChanged: () => changedCount++,
          );
        },
        seed: () => CategoryLoaded(tCategories),
        act: (bloc) => bloc.add(const UpdateCategory(id: 'cat-1', name: '부모님')),
        verify: (_) => expect(changedCount, 1),
      );

      blocTest<CategoryBloc, CategoryState>(
        'does NOT invoke onChanged when update fails',
        build: () {
          when(mockRepository.updateCategory(id: 'cat-1', name: '부모님'))
              .thenAnswer(
                  (_) async => const Left(ServerFailure('update failed')));
          changedCount = 0;
          return CategoryBloc(
            categoryRepository: mockRepository,
            onChanged: () => changedCount++,
          );
        },
        seed: () => CategoryLoaded(tCategories),
        act: (bloc) => bloc.add(const UpdateCategory(id: 'cat-1', name: '부모님')),
        verify: (_) => expect(changedCount, 0),
      );

      blocTest<CategoryBloc, CategoryState>(
        'invokes onChanged after successful delete',
        build: () {
          when(mockRepository.deleteCategory('cat-1'))
              .thenAnswer((_) async => const Right(null));
          changedCount = 0;
          return CategoryBloc(
            categoryRepository: mockRepository,
            onChanged: () => changedCount++,
          );
        },
        seed: () => CategoryLoaded(tCategories),
        act: (bloc) => bloc.add(const DeleteCategory('cat-1')),
        verify: (_) => expect(changedCount, 1),
      );
    });
  });

  group('CategoryLoaded', () {
    test('incomeCategories returns only INCOME type', () {
      final state = CategoryLoaded(tCategories);
      expect(state.incomeCategories, [tIncomeCategory]);
    });

    test('expenseCategories returns only EXPENSE type', () {
      final state = CategoryLoaded(tCategories);
      expect(state.expenseCategories, [tExpenseCategory]);
    });
  });
}
