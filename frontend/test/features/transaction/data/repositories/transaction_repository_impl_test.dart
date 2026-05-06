import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:budget_book/features/transaction/data/datasources/transaction_remote_datasource.dart';
import 'package:budget_book/features/transaction/data/models/transaction_model.dart';
import 'package:budget_book/features/transaction/data/models/transaction_author_model.dart';
import 'package:budget_book/features/transaction/data/models/transaction_category_model.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';

class MockTransactionRemoteDataSource extends Mock
    implements TransactionRemoteDataSource {
  @override
  Future<PageResponse<TransactionModel>> getTransactions({
    int? year,
    int? month,
    String? type,
    Set<String> transactionTypes = const {},
    String? categoryId,
    Set<String> categoryIds = const {},
    Set<String> categoryGroupIds = const {},
    String? keyword,
    String? paymentMethodId,
    Set<String> paymentMethodIds = const {},
    String? pocketId,
    Set<String> pocketIds = const {},
    int? amountMin,
    int? amountMax,
    String? dateFrom,
    String? dateTo,
    String? visibility,
    bool? needsReviewOnly,
    int page = 0,
    int size = 20,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getTransactions, [], {
          #year: year,
          #month: month,
          #type: type,
          #transactionTypes: transactionTypes,
          #categoryId: categoryId,
          #categoryIds: categoryIds,
          #categoryGroupIds: categoryGroupIds,
          #keyword: keyword,
          #paymentMethodId: paymentMethodId,
          #paymentMethodIds: paymentMethodIds,
          #pocketId: pocketId,
          #pocketIds: pocketIds,
          #amountMin: amountMin,
          #amountMax: amountMax,
          #dateFrom: dateFrom,
          #dateTo: dateTo,
          #visibility: visibility,
          #needsReviewOnly: needsReviewOnly,
          #page: page,
          #size: size,
        }),
        returnValue: Future.value(
          const PageResponse<TransactionModel>(
            content: [],
            page: 0,
            size: 20,
            totalElements: 0,
            totalPages: 0,
            first: true,
            last: true,
          ),
        ),
      ) as Future<PageResponse<TransactionModel>>;

  @override
  Future<TransactionModel> getTransaction(String id) => super.noSuchMethod(
        Invocation.method(#getTransaction, [id]),
        returnValue: Future.value(_dummyModel),
      ) as Future<TransactionModel>;

  @override
  Future<TransactionModel> createTransaction(Map<String, dynamic> data) =>
      super.noSuchMethod(
        Invocation.method(#createTransaction, [data]),
        returnValue: Future.value(_dummyModel),
      ) as Future<TransactionModel>;

  @override
  Future<TransactionModel> updateTransaction(
          String id, Map<String, dynamic> data) =>
      super.noSuchMethod(
        Invocation.method(#updateTransaction, [id, data]),
        returnValue: Future.value(_dummyModel),
      ) as Future<TransactionModel>;

  @override
  Future<void> deleteTransaction(String id) => super.noSuchMethod(
        Invocation.method(#deleteTransaction, [id]),
        returnValue: Future.value(),
      ) as Future<void>;

  @override
  Future<List<SuggestionGroup>> getSuggestions(String query) =>
      super.noSuchMethod(
        Invocation.method(#getSuggestions, [query]),
        returnValue: Future.value(<SuggestionGroup>[]),
      ) as Future<List<SuggestionGroup>>;

  static final _dummyModel = TransactionModel(
    id: '',
    coupleId: '',
    author: const TransactionAuthorModel(id: '', nickname: ''),
    type: 'EXPENSE',
    amount: 0,
    description: '',
    transactionDate: '2024-01-01',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

void main() {
  late TransactionRepositoryImpl repository;
  late MockTransactionRemoteDataSource mockDataSource;

  final tTransactionModel = TransactionModel(
    id: 'txn-1',
    coupleId: 'couple-1',
    author: const TransactionAuthorModel(
      id: 'user-1',
      nickname: '홍길동',
      profileImageUrl: 'https://example.com/photo.jpg',
    ),
    category: const TransactionCategoryModel(
      id: 'cat-1',
      name: '식비',
      type: 'EXPENSE',
      icon: 'restaurant',
      color: '#FF5733',
    ),
    type: 'EXPENSE',
    amount: 15000,
    description: '점심 식사',
    memo: '팀 점심',
    transactionDate: '2024-01-15',
    createdAt: DateTime.parse('2024-01-15T12:30:00Z'),
    updatedAt: DateTime.parse('2024-01-15T12:30:00Z'),
  );

  final tPageResponse = PageResponse<TransactionModel>(
    content: [tTransactionModel],
    page: 0,
    size: 20,
    totalElements: 1,
    totalPages: 1,
    first: true,
    last: true,
  );

  setUp(() {
    mockDataSource = MockTransactionRemoteDataSource();
    repository =
        TransactionRepositoryImpl(remoteDataSource: mockDataSource);
  });

  group('TransactionRepositoryImpl', () {
    group('getTransactions', () {
      test('returns Right(PageResponse) when datasource succeeds', () async {
        when(mockDataSource.getTransactions(
          year: 2024,
          month: 1,
          page: 0,
          size: 20,
        )).thenAnswer((_) async => tPageResponse);

        final result =
            await repository.getTransactions(year: 2024, month: 1);

        expect(
          result,
          equals(
              Right<Failure, PageResponse<Transaction>>(tPageResponse)),
        );
        verify(mockDataSource.getTransactions(
          year: 2024,
          month: 1,
          page: 0,
          size: 20,
        )).called(1);
      });

      test('returns Left(ServerFailure) on DioException', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/transactions'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/transactions'),
            statusCode: 500,
            data: {
              'error': {'message': 'Internal server error'},
            },
          ),
        );
        when(mockDataSource.getTransactions(
          year: 2024,
          month: 1,
          page: 0,
          size: 20,
        )).thenAnswer((_) async => throw dioException);

        final result =
            await repository.getTransactions(year: 2024, month: 1);

        expect(
          result,
          equals(const Left<Failure, PageResponse<Transaction>>(
              ServerFailure('Internal server error', null, 500))),
        );
      });
    });

    group('getTransaction', () {
      test('returns Right(Transaction) when datasource succeeds', () async {
        when(mockDataSource.getTransaction('txn-1'))
            .thenAnswer((_) async => tTransactionModel);

        final result = await repository.getTransaction('txn-1');

        expect(result,
            equals(Right<Failure, Transaction>(tTransactionModel)));
      });

      test('returns Left(ServerFailure) on not found', () async {
        final dioException = DioException(
          requestOptions:
              RequestOptions(path: '/api/v1/transactions/txn-999'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/api/v1/transactions/txn-999'),
            statusCode: 404,
            data: {
              'error': {'message': 'Transaction does not exist'},
            },
          ),
        );
        when(mockDataSource.getTransaction('txn-999'))
            .thenAnswer((_) async => throw dioException);

        final result = await repository.getTransaction('txn-999');

        expect(
          result,
          equals(const Left<Failure, Transaction>(
              ServerFailure('Transaction does not exist', null, 404))),
        );
      });
    });

    group('createTransaction', () {
      test('returns Right(Transaction) when datasource succeeds', () async {
        final expectedData = {
          'type': 'EXPENSE',
          'amount': 15000,
          'description': '점심 식사',
          'transactionDate': '2024-01-15',
          'categoryId': 'cat-1',
          'memo': '팀 점심',
          // V61 (2026-05-06) — repo 가 항상 needsReview 포함하여 전송
          'needsReview': false,
        };
        when(mockDataSource.createTransaction(expectedData))
            .thenAnswer((_) async => tTransactionModel);

        final result = await repository.createTransaction(
          type: 'EXPENSE',
          amount: 15000,
          description: '점심 식사',
          categoryId: 'cat-1',
          transactionDate: '2024-01-15',
          memo: '팀 점심',
        );

        expect(result,
            equals(Right<Failure, Transaction>(tTransactionModel)));
      });

      test('returns Left(ServerFailure) on validation error', () async {
        final expectedData = {
          'type': 'EXPENSE',
          'amount': 0,
          'description': '',
          'transactionDate': '2024-01-15',
          // V61 (2026-05-06) — repo 가 항상 needsReview 포함하여 전송
          'needsReview': false,
        };
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/transactions'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/transactions'),
            statusCode: 400,
            data: {
              'error': {'message': 'Invalid field values'},
            },
          ),
        );
        when(mockDataSource.createTransaction(expectedData))
            .thenAnswer((_) async => throw dioException);

        final result = await repository.createTransaction(
          type: 'EXPENSE',
          amount: 0,
          description: '',
          transactionDate: '2024-01-15',
        );

        expect(
          result,
          equals(const Left<Failure, Transaction>(
              ServerFailure('Invalid field values', null, 400))),
        );
      });
    });

    group('updateTransaction', () {
      test('returns Right(Transaction) when datasource succeeds', () async {
        final expectedData = {
          'amount': 20000,
          'description': '점심 + 커피',
        };
        when(mockDataSource.updateTransaction('txn-1', expectedData))
            .thenAnswer((_) async => tTransactionModel);

        final result = await repository.updateTransaction(
          id: 'txn-1',
          amount: 20000,
          description: '점심 + 커피',
        );

        expect(result,
            equals(Right<Failure, Transaction>(tTransactionModel)));
      });

      test('sends memo: null when clearMemo is true', () async {
        final expectedData = {
          'amount': 20000,
          'memo': null,
        };
        when(mockDataSource.updateTransaction('txn-1', expectedData))
            .thenAnswer((_) async => tTransactionModel);

        final result = await repository.updateTransaction(
          id: 'txn-1',
          amount: 20000,
          clearMemo: true,
        );

        expect(result,
            equals(Right<Failure, Transaction>(tTransactionModel)));
        verify(mockDataSource.updateTransaction('txn-1', expectedData))
            .called(1);
      });

      test('returns Left(ServerFailure) on forbidden', () async {
        final expectedData = {'amount': 20000};
        final dioException = DioException(
          requestOptions:
              RequestOptions(path: '/api/v1/transactions/txn-1'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/api/v1/transactions/txn-1'),
            statusCode: 403,
            data: {
              'error': {
                'message': 'Transaction belongs to a different couple'
              },
            },
          ),
        );
        when(mockDataSource.updateTransaction('txn-1', expectedData))
            .thenAnswer((_) async => throw dioException);

        final result = await repository.updateTransaction(
          id: 'txn-1',
          amount: 20000,
        );

        expect(
          result,
          equals(const Left<Failure, Transaction>(
              ServerFailure('Transaction belongs to a different couple', null, 403))),
        );
      });
    });

    group('deleteTransaction', () {
      test('returns Right(null) when datasource succeeds', () async {
        when(mockDataSource.deleteTransaction('txn-1'))
            .thenAnswer((_) async {});

        final result = await repository.deleteTransaction('txn-1');

        expect(result, equals(const Right<Failure, void>(null)));
        verify(mockDataSource.deleteTransaction('txn-1')).called(1);
      });

      test('returns Left(ServerFailure) on not found', () async {
        final dioException = DioException(
          requestOptions:
              RequestOptions(path: '/api/v1/transactions/txn-1'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/api/v1/transactions/txn-1'),
            statusCode: 404,
            data: {
              'error': {'message': 'Transaction does not exist'},
            },
          ),
        );
        when(mockDataSource.deleteTransaction('txn-1'))
            .thenAnswer((_) async => throw dioException);

        final result = await repository.deleteTransaction('txn-1');

        expect(
          result,
          equals(const Left<Failure, void>(
              ServerFailure('Transaction does not exist', null, 404))),
        );
      });
    });

    group('getSuggestions', () {
      test('returns Right(List<SuggestionGroup>) when datasource succeeds', () async {
        final suggestions = [
          const SuggestionGroup(description: '점심 식사', patterns: []),
          const SuggestionGroup(description: '점심 커피', patterns: []),
          const SuggestionGroup(description: '점심 도시락', patterns: []),
        ];
        when(mockDataSource.getSuggestions('점심'))
            .thenAnswer((_) async => suggestions);

        final result = await repository.getSuggestions('점심');

        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('Expected Right'),
          (data) => expect(data.length, 3),
        );
        verify(mockDataSource.getSuggestions('점심')).called(1);
      });

      test('returns empty list when no suggestions', () async {
        when(mockDataSource.getSuggestions('zzz'))
            .thenAnswer((_) async => <SuggestionGroup>[]);

        final result = await repository.getSuggestions('zzz');

        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('Expected Right'),
          (data) => expect(data, isEmpty),
        );
      });

      test('returns Left(ServerFailure) on DioException', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(
              path: '/api/v1/transactions/suggestions'),
          response: Response(
            requestOptions: RequestOptions(
                path: '/api/v1/transactions/suggestions'),
            statusCode: 500,
            data: {
              'error': {'message': 'Internal server error'},
            },
          ),
        );
        when(mockDataSource.getSuggestions('점심'))
            .thenAnswer((_) async => throw dioException);

        final result = await repository.getSuggestions('점심');

        expect(
          result,
          equals(const Left<Failure, List<String>>(
              ServerFailure('Internal server error', null, 500))),
        );
      });

      test('returns Left(ServerFailure) on generic exception', () async {
        when(mockDataSource.getSuggestions('점심'))
            .thenAnswer((_) async => throw Exception('unexpected'));

        final result = await repository.getSuggestions('점심');

        expect(
          result,
          equals(const Left<Failure, List<String>>(
              ServerFailure('Failed to load suggestions'))),
        );
      });
    });
  });
}
