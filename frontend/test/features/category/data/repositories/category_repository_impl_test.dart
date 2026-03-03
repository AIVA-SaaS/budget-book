import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/features/category/data/repositories/category_repository_impl.dart';
import 'package:budget_book/features/category/data/datasources/category_remote_datasource.dart';
import 'package:budget_book/features/category/data/models/category_model.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/core/error/failure.dart';

class MockCategoryRemoteDataSource extends Mock
    implements CategoryRemoteDataSource {
  @override
  Future<List<CategoryModel>> getCategories({String? type}) =>
      super.noSuchMethod(
        Invocation.method(#getCategories, [], {#type: type}),
        returnValue: Future.value(<CategoryModel>[]),
      ) as Future<List<CategoryModel>>;

  @override
  Future<CategoryModel> createCategory(Map<String, dynamic> data) =>
      super.noSuchMethod(
        Invocation.method(#createCategory, [data]),
        returnValue: Future.value(CategoryModel(
          id: '',
          name: '',
          type: 'EXPENSE',
          isDefault: false,
          displayOrder: 0,
          createdAt: DateTime(2024),
        )),
      ) as Future<CategoryModel>;

  @override
  Future<CategoryModel> updateCategory(
          String id, Map<String, dynamic> data) =>
      super.noSuchMethod(
        Invocation.method(#updateCategory, [id, data]),
        returnValue: Future.value(CategoryModel(
          id: '',
          name: '',
          type: 'EXPENSE',
          isDefault: false,
          displayOrder: 0,
          createdAt: DateTime(2024),
        )),
      ) as Future<CategoryModel>;

  @override
  Future<void> deleteCategory(String id) => super.noSuchMethod(
        Invocation.method(#deleteCategory, [id]),
        returnValue: Future.value(),
      ) as Future<void>;
}

void main() {
  late CategoryRepositoryImpl repository;
  late MockCategoryRemoteDataSource mockDataSource;

  final tCategoryModel = CategoryModel(
    id: 'cat-1',
    name: '식비',
    type: 'EXPENSE',
    icon: 'restaurant',
    color: '#FF5733',
    isDefault: true,
    displayOrder: 1,
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tCategoryModels = [tCategoryModel];

  setUp(() {
    mockDataSource = MockCategoryRemoteDataSource();
    repository = CategoryRepositoryImpl(remoteDataSource: mockDataSource);
  });

  group('CategoryRepositoryImpl', () {
    group('getCategories', () {
      test('returns Right(List<Category>) when datasource succeeds', () async {
        when(mockDataSource.getCategories(type: null))
            .thenAnswer((_) async => tCategoryModels);

        final result = await repository.getCategories();

        expect(result,
            equals(Right<Failure, List<Category>>(tCategoryModels)));
        verify(mockDataSource.getCategories(type: null)).called(1);
      });

      test('passes type filter to datasource', () async {
        when(mockDataSource.getCategories(type: 'INCOME'))
            .thenAnswer((_) async => []);

        await repository.getCategories(type: 'INCOME');

        verify(mockDataSource.getCategories(type: 'INCOME')).called(1);
      });

      test('returns Left(ServerFailure) on DioException', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/categories'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/categories'),
            statusCode: 500,
            data: {
              'error': {'message': 'Internal server error'},
            },
          ),
        );
        when(mockDataSource.getCategories(type: null))
            .thenAnswer((_) async => throw dioException);

        final result = await repository.getCategories();

        expect(
          result,
          equals(const Left<Failure, List<Category>>(
              ServerFailure('Internal server error', null, 500))),
        );
      });

      test('returns Left with default message when error body is null',
          () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/categories'),
        );
        when(mockDataSource.getCategories(type: null))
            .thenAnswer((_) async => throw dioException);

        final result = await repository.getCategories();

        expect(
          result,
          equals(const Left<Failure, List<Category>>(
              ServerFailure('Failed to load categories'))),
        );
      });
    });

    group('createCategory', () {
      test('returns Right(Category) when datasource succeeds', () async {
        final newModel = CategoryModel(
          id: 'cat-new',
          name: '반려동물',
          type: 'EXPENSE',
          icon: 'pets',
          color: '#9C27B0',
          isDefault: false,
          displayOrder: 10,
          createdAt: DateTime.parse('2024-01-15T12:00:00Z'),
        );
        final expectedData = {
          'name': '반려동물',
          'type': 'EXPENSE',
          'icon': 'pets',
          'color': '#9C27B0',
        };
        when(mockDataSource.createCategory(expectedData))
            .thenAnswer((_) async => newModel);

        final result = await repository.createCategory(
          name: '반려동물',
          type: 'EXPENSE',
          icon: 'pets',
          color: '#9C27B0',
        );

        expect(result, equals(Right<Failure, Category>(newModel)));
        verify(mockDataSource.createCategory(expectedData)).called(1);
      });

      test('returns Left(ServerFailure) on validation error', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/categories'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/categories'),
            statusCode: 400,
            data: {
              'error': {'message': 'Invalid category name'},
            },
          ),
        );
        when(mockDataSource.createCategory({'name': '', 'type': 'EXPENSE'}))
            .thenAnswer((_) async => throw dioException);

        final result = await repository.createCategory(
          name: '',
          type: 'EXPENSE',
        );

        expect(
          result,
          equals(const Left<Failure, Category>(
              ServerFailure('Invalid category name', null, 400))),
        );
      });
    });

    group('updateCategory', () {
      test('returns Right(Category) when datasource succeeds', () async {
        final updatedModel = CategoryModel(
          id: 'cat-1',
          name: '식비/외식',
          type: 'EXPENSE',
          icon: 'restaurant_menu',
          color: '#E91E63',
          isDefault: true,
          displayOrder: 1,
          createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
        );
        final expectedData = {
          'name': '식비/외식',
          'icon': 'restaurant_menu',
          'color': '#E91E63',
        };
        when(mockDataSource.updateCategory('cat-1', expectedData))
            .thenAnswer((_) async => updatedModel);

        final result = await repository.updateCategory(
          id: 'cat-1',
          name: '식비/외식',
          icon: 'restaurant_menu',
          color: '#E91E63',
        );

        expect(result, equals(Right<Failure, Category>(updatedModel)));
      });

      test('returns Left(ServerFailure) when category not found', () async {
        final dioException = DioException(
          requestOptions:
              RequestOptions(path: '/api/v1/categories/non-existent'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/api/v1/categories/non-existent'),
            statusCode: 404,
            data: {
              'error': {'message': 'Category does not exist'},
            },
          ),
        );
        when(mockDataSource.updateCategory('non-existent', {'name': 'updated'}))
            .thenAnswer((_) async => throw dioException);

        final result = await repository.updateCategory(
          id: 'non-existent',
          name: 'updated',
        );

        expect(
          result,
          equals(const Left<Failure, Category>(
              ServerFailure('Category does not exist', null, 404))),
        );
      });
    });

    group('deleteCategory', () {
      test('returns Right(null) when datasource succeeds', () async {
        when(mockDataSource.deleteCategory('cat-1'))
            .thenAnswer((_) async {});

        final result = await repository.deleteCategory('cat-1');

        expect(result, equals(const Right<Failure, void>(null)));
        verify(mockDataSource.deleteCategory('cat-1')).called(1);
      });

      test('returns Left(ServerFailure) when deleting default category',
          () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/categories/cat-1'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/api/v1/categories/cat-1'),
            statusCode: 400,
            data: {
              'error': {'message': 'Default categories cannot be deleted'},
            },
          ),
        );
        when(mockDataSource.deleteCategory('cat-1'))
            .thenAnswer((_) async => throw dioException);

        final result = await repository.deleteCategory('cat-1');

        expect(
          result,
          equals(const Left<Failure, void>(
              ServerFailure('Default categories cannot be deleted', null, 400))),
        );
      });
    });
  });
}
