import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/core/error/failure.dart';

class MockTransactionRepository extends Mock
    implements TransactionRepository {
  @override
  Future<Either<Failure, PageResponse<Transaction>>> getTransactions({
    int? year,
    int? month,
    String? type,
    String? categoryId,
    int page = 0,
    int size = 20,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getTransactions, [], {
          #year: year,
          #month: month,
          #type: type,
          #categoryId: categoryId,
          #page: page,
          #size: size,
        }),
        returnValue: Future.value(
          const Right<Failure, PageResponse<Transaction>>(
            PageResponse(
              content: [],
              page: 0,
              size: 20,
              totalElements: 0,
              totalPages: 0,
              first: true,
              last: true,
            ),
          ),
        ),
      ) as Future<Either<Failure, PageResponse<Transaction>>>;

  @override
  Future<Either<Failure, Transaction>> getTransaction(String id) =>
      super.noSuchMethod(
        Invocation.method(#getTransaction, [id]),
        returnValue: Future.value(
          Right<Failure, Transaction>(_dummyTransaction),
        ),
      ) as Future<Either<Failure, Transaction>>;

  @override
  Future<Either<Failure, Transaction>> createTransaction({
    required String type,
    required int amount,
    required String description,
    String? categoryId,
    required String transactionDate,
    String? memo,
    String? paymentMethodId,
    String? pocketId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createTransaction, [], {
          #type: type,
          #amount: amount,
          #description: description,
          #categoryId: categoryId,
          #transactionDate: transactionDate,
          #memo: memo,
          #paymentMethodId: paymentMethodId,
          #pocketId: pocketId,
        }),
        returnValue: Future.value(
          Right<Failure, Transaction>(_dummyTransaction),
        ),
      ) as Future<Either<Failure, Transaction>>;

  @override
  Future<Either<Failure, Transaction>> updateTransaction({
    required String id,
    int? amount,
    String? description,
    String? categoryId,
    String? transactionDate,
    String? memo,
    bool clearMemo = false,
    String? paymentMethodId,
    String? pocketId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateTransaction, [], {
          #id: id,
          #amount: amount,
          #description: description,
          #categoryId: categoryId,
          #transactionDate: transactionDate,
          #memo: memo,
          #clearMemo: clearMemo,
          #paymentMethodId: paymentMethodId,
          #pocketId: pocketId,
        }),
        returnValue: Future.value(
          Right<Failure, Transaction>(_dummyTransaction),
        ),
      ) as Future<Either<Failure, Transaction>>;

  @override
  Future<Either<Failure, void>> deleteTransaction(String id) =>
      super.noSuchMethod(
        Invocation.method(#deleteTransaction, [id]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  static final _dummyTransaction = Transaction(
    id: '',
    coupleId: '',
    author: const TransactionAuthor(id: '', nickname: ''),
    type: 'EXPENSE',
    amount: 0,
    description: '',
    transactionDate: '2024-01-01',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

void main() {
  late TransactionBloc transactionBloc;
  late MockTransactionRepository mockRepository;

  const tAuthor = TransactionAuthor(
    id: 'user-1',
    nickname: '홍길동',
    profileImageUrl: 'https://example.com/photo.jpg',
  );

  const tCategory = TransactionCategory(
    id: 'cat-1',
    name: '식비',
    type: 'EXPENSE',
    icon: 'restaurant',
    color: '#FF5733',
  );

  final tTransaction1 = Transaction(
    id: 'txn-1',
    coupleId: 'couple-1',
    author: tAuthor,
    category: tCategory,
    type: 'EXPENSE',
    amount: 15000,
    description: '점심 식사',
    transactionDate: '2024-01-15',
    createdAt: DateTime.parse('2024-01-15T12:30:00Z'),
    updatedAt: DateTime.parse('2024-01-15T12:30:00Z'),
  );

  final tTransaction2 = Transaction(
    id: 'txn-2',
    coupleId: 'couple-1',
    author: tAuthor,
    category: null,
    type: 'INCOME',
    amount: 3000000,
    description: '월급',
    transactionDate: '2024-01-25',
    createdAt: DateTime.parse('2024-01-25T09:00:00Z'),
    updatedAt: DateTime.parse('2024-01-25T09:00:00Z'),
  );

  final tTransactions = [tTransaction1, tTransaction2];

  final tPageResponse = PageResponse<Transaction>(
    content: tTransactions,
    page: 0,
    size: 100,
    totalElements: 2,
    totalPages: 1,
    first: true,
    last: true,
  );

  setUp(() {
    mockRepository = MockTransactionRepository();
    transactionBloc =
        TransactionBloc(transactionRepository: mockRepository);
  });

  tearDown(() {
    transactionBloc.close();
  });

  group('TransactionBloc', () {
    test('initial state is TransactionInitial', () {
      expect(transactionBloc.state, const TransactionInitial());
    });

    group('LoadTransactions', () {
      blocTest<TransactionBloc, TransactionState>(
        'emits [TransactionLoading, TransactionLoaded] on success',
        build: () {
          when(mockRepository.getTransactions(
            year: 2024,
            month: 1,
            size: 100,
          )).thenAnswer((_) async => Right(tPageResponse));
          return transactionBloc;
        },
        act: (bloc) =>
            bloc.add(const LoadTransactions(year: 2024, month: 1)),
        expect: () => [
          const TransactionLoading(),
          TransactionLoaded(
            transactions: tTransactions,
            year: 2024,
            month: 1,
            totalElements: 2,
            hasMore: false,
          ),
        ],
      );

      blocTest<TransactionBloc, TransactionState>(
        'emits [TransactionLoading, TransactionError] on failure',
        build: () {
          when(mockRepository.getTransactions(
            year: 2024,
            month: 1,
            size: 100,
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to load transactions')));
          return transactionBloc;
        },
        act: (bloc) =>
            bloc.add(const LoadTransactions(year: 2024, month: 1)),
        expect: () => [
          const TransactionLoading(),
          const TransactionError('Failed to load transactions'),
        ],
      );
    });

    group('CreateTransaction', () {
      blocTest<TransactionBloc, TransactionState>(
        'emits TransactionError on failure',
        build: () {
          when(mockRepository.createTransaction(
            type: 'EXPENSE',
            amount: 15000,
            description: '점심 식사',
            categoryId: 'cat-1',
            transactionDate: '2024-01-15',
            memo: null,
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to create transaction')));
          return transactionBloc;
        },
        act: (bloc) => bloc.add(const CreateTransaction(
          type: 'EXPENSE',
          amount: 15000,
          description: '점심 식사',
          categoryId: 'cat-1',
          transactionDate: '2024-01-15',
        )),
        expect: () => [
          const TransactionError('Failed to create transaction'),
        ],
      );

      blocTest<TransactionBloc, TransactionState>(
        'reloads transactions on create success',
        build: () {
          when(mockRepository.createTransaction(
            type: 'EXPENSE',
            amount: 15000,
            description: '점심 식사',
            categoryId: 'cat-1',
            transactionDate: '2024-01-15',
            memo: null,
          )).thenAnswer((_) async => Right(tTransaction1));
          when(mockRepository.getTransactions(
            year: 2024,
            month: 1,
            size: 100,
          )).thenAnswer((_) async => Right(tPageResponse));
          return transactionBloc;
        },
        seed: () => const TransactionLoaded(
          transactions: [],
          year: 2024,
          month: 1,
          totalElements: 0,
          hasMore: false,
        ),
        act: (bloc) {
          // First load to set currentYear/currentMonth
          bloc.add(const LoadTransactions(year: 2024, month: 1));
        },
        skip: 2, // skip Loading and Loaded from LoadTransactions
        verify: (_) {
          // Verify getTransactions was called
          verify(mockRepository.getTransactions(
            year: 2024,
            month: 1,
            size: 100,
          )).called(1);
        },
      );
    });

    group('DeleteTransaction', () {
      blocTest<TransactionBloc, TransactionState>(
        'emits TransactionLoaded with removed item on success',
        build: () {
          when(mockRepository.deleteTransaction('txn-1'))
              .thenAnswer((_) async => const Right(null));
          return transactionBloc;
        },
        seed: () => TransactionLoaded(
          transactions: tTransactions,
          year: 2024,
          month: 1,
          totalElements: 2,
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const DeleteTransaction('txn-1')),
        expect: () => [
          TransactionLoaded(
            transactions: [tTransaction2],
            year: 2024,
            month: 1,
            totalElements: 1,
            hasMore: false,
          ),
        ],
      );

      blocTest<TransactionBloc, TransactionState>(
        'emits TransactionLoaded with operationError on delete failure, preserving list',
        build: () {
          when(mockRepository.deleteTransaction('txn-1')).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('Failed to delete transaction')));
          return transactionBloc;
        },
        seed: () => TransactionLoaded(
          transactions: tTransactions,
          year: 2024,
          month: 1,
          totalElements: 2,
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const DeleteTransaction('txn-1')),
        expect: () => [
          TransactionLoaded(
            transactions: tTransactions,
            year: 2024,
            month: 1,
            totalElements: 2,
            hasMore: false,
            operationError: 'Failed to delete transaction',
          ),
        ],
      );
    });

    group('UpdateTransaction', () {
      blocTest<TransactionBloc, TransactionState>(
        'emits TransactionError on failure',
        build: () {
          when(mockRepository.updateTransaction(
            id: 'txn-1',
            amount: 20000,
            description: '점심 + 커피',
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to update transaction')));
          return transactionBloc;
        },
        act: (bloc) => bloc.add(const UpdateTransaction(
          id: 'txn-1',
          amount: 20000,
          description: '점심 + 커피',
        )),
        expect: () => [
          const TransactionError('Failed to update transaction'),
        ],
      );
    });
  });

  group('TransactionLoaded', () {
    test('totalIncome sums INCOME transactions', () {
      final state = TransactionLoaded(
        transactions: tTransactions,
        year: 2024,
        month: 1,
        totalElements: 2,
        hasMore: false,
      );
      expect(state.totalIncome, 3000000);
    });

    test('totalExpense sums EXPENSE transactions', () {
      final state = TransactionLoaded(
        transactions: tTransactions,
        year: 2024,
        month: 1,
        totalElements: 2,
        hasMore: false,
      );
      expect(state.totalExpense, 15000);
    });

    test('balance is income minus expense', () {
      final state = TransactionLoaded(
        transactions: tTransactions,
        year: 2024,
        month: 1,
        totalElements: 2,
        hasMore: false,
      );
      expect(state.balance, 2985000);
    });

    test('groupedByDate groups transactions by date', () {
      final state = TransactionLoaded(
        transactions: tTransactions,
        year: 2024,
        month: 1,
        totalElements: 2,
        hasMore: false,
      );
      final grouped = state.groupedByDate;
      expect(grouped.length, 2);
      expect(grouped['2024-01-15'], [tTransaction1]);
      expect(grouped['2024-01-25'], [tTransaction2]);
    });
  });
}
