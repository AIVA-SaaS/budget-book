import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_bloc.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_event.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_state.dart';
import 'package:budget_book/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:budget_book/features/recurring/domain/entities/recurring_transaction.dart';
import 'package:budget_book/core/error/failure.dart';

class MockRecurringRepository extends Mock implements RecurringRepository {
  @override
  Future<Either<Failure, List<RecurringTransaction>>>
      getRecurringTransactions() =>
          super.noSuchMethod(
            Invocation.method(#getRecurringTransactions, []),
            returnValue: Future.value(
              const Right<Failure, List<RecurringTransaction>>([]),
            ),
          ) as Future<Either<Failure, List<RecurringTransaction>>>;

  @override
  Future<Either<Failure, RecurringTransaction>> createRecurringTransaction({
    required String type,
    required int amount,
    required String description,
    String? memo,
    required String frequency,
    int? dayOfMonth,
    int? dayOfWeek,
    String? categoryId,
    String? paymentMethodId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createRecurringTransaction, [], {
          #type: type,
          #amount: amount,
          #description: description,
          #memo: memo,
          #frequency: frequency,
          #dayOfMonth: dayOfMonth,
          #dayOfWeek: dayOfWeek,
          #categoryId: categoryId,
          #paymentMethodId: paymentMethodId,
        }),
        returnValue: Future.value(
          Right<Failure, RecurringTransaction>(RecurringTransaction(
            id: '',
            type: 'EXPENSE',
            amount: 0,
            description: '',
            frequency: 'MONTHLY',
            nextRunDate: '',
            isActive: true,
            createdAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, RecurringTransaction>>;

  @override
  Future<Either<Failure, RecurringTransaction>> updateRecurringTransaction({
    required String id,
    int? amount,
    String? description,
    String? memo,
    String? categoryId,
    String? paymentMethodId,
    int? dayOfMonth,
    int? dayOfWeek,
    bool? isActive,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateRecurringTransaction, [], {
          #id: id,
          #amount: amount,
          #description: description,
          #memo: memo,
          #categoryId: categoryId,
          #paymentMethodId: paymentMethodId,
          #dayOfMonth: dayOfMonth,
          #dayOfWeek: dayOfWeek,
          #isActive: isActive,
        }),
        returnValue: Future.value(
          Right<Failure, RecurringTransaction>(RecurringTransaction(
            id: '',
            type: 'EXPENSE',
            amount: 0,
            description: '',
            frequency: 'MONTHLY',
            nextRunDate: '',
            isActive: true,
            createdAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, RecurringTransaction>>;

  @override
  Future<Either<Failure, void>> deleteRecurringTransaction(String id) =>
      super.noSuchMethod(
        Invocation.method(#deleteRecurringTransaction, [id]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;
}

void main() {
  late RecurringBloc bloc;
  late MockRecurringRepository mockRepository;

  final tRent = RecurringTransaction(
    id: 'r1',
    type: 'EXPENSE',
    amount: 700000,
    description: '월세',
    frequency: 'MONTHLY',
    dayOfMonth: 25,
    nextRunDate: '2026-04-25',
    lastRunDate: '2026-03-25',
    isActive: true,
    categoryName: '월세',
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tSalary = RecurringTransaction(
    id: 'r2',
    type: 'INCOME',
    amount: 3500000,
    description: '급여',
    frequency: 'MONTHLY',
    dayOfMonth: 1,
    nextRunDate: '2026-04-01',
    lastRunDate: '2026-03-01',
    isActive: true,
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tTransactions = [tRent, tSalary];

  final tNewRecurring = RecurringTransaction(
    id: 'r3',
    type: 'EXPENSE',
    amount: 15000,
    description: '구독',
    frequency: 'MONTHLY',
    dayOfMonth: 15,
    nextRunDate: '2026-04-15',
    isActive: true,
    createdAt: DateTime.parse('2024-02-01T12:00:00Z'),
  );

  setUp(() {
    mockRepository = MockRecurringRepository();
    bloc = RecurringBloc(recurringRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('RecurringBloc', () {
    test('initial state is RecurringInitial', () {
      expect(bloc.state, const RecurringInitial());
    });

    group('LoadRecurringTransactions', () {
      blocTest<RecurringBloc, RecurringState>(
        'emits [Loading, Loaded] on success',
        build: () {
          when(mockRepository.getRecurringTransactions())
              .thenAnswer((_) async => Right(tTransactions));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadRecurringTransactions()),
        expect: () => [
          const RecurringLoading(),
          RecurringLoaded(tTransactions),
        ],
      );

      blocTest<RecurringBloc, RecurringState>(
        'emits [Loading, Error] on failure',
        build: () {
          when(mockRepository.getRecurringTransactions()).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('반복 거래를 불러오지 못했습니다')));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadRecurringTransactions()),
        expect: () => [
          const RecurringLoading(),
          const RecurringError('반복 거래를 불러오지 못했습니다'),
        ],
      );
    });

    group('CreateRecurringTransaction', () {
      blocTest<RecurringBloc, RecurringState>(
        'emits [Loaded] with new transaction appended',
        build: () {
          when(mockRepository.createRecurringTransaction(
            type: 'EXPENSE',
            amount: 15000,
            description: '구독',
            memo: null,
            frequency: 'MONTHLY',
            dayOfMonth: 15,
            dayOfWeek: null,
            categoryId: null,
            paymentMethodId: null,
          )).thenAnswer((_) async => Right(tNewRecurring));
          return bloc;
        },
        seed: () => RecurringLoaded(tTransactions),
        act: (bloc) => bloc.add(const CreateRecurringTransaction(
          type: 'EXPENSE',
          amount: 15000,
          description: '구독',
          frequency: 'MONTHLY',
          dayOfMonth: 15,
        )),
        expect: () => [
          RecurringLoaded([...tTransactions, tNewRecurring]),
        ],
      );

      blocTest<RecurringBloc, RecurringState>(
        'emits [Loaded with operationError] on failure',
        build: () {
          when(mockRepository.createRecurringTransaction(
            type: 'EXPENSE',
            amount: 15000,
            description: '구독',
            memo: null,
            frequency: 'MONTHLY',
            dayOfMonth: 15,
            dayOfWeek: null,
            categoryId: null,
            paymentMethodId: null,
          )).thenAnswer((_) async =>
              const Left(ServerFailure('반복 거래를 생성하지 못했습니다')));
          return bloc;
        },
        seed: () => RecurringLoaded(tTransactions),
        act: (bloc) => bloc.add(const CreateRecurringTransaction(
          type: 'EXPENSE',
          amount: 15000,
          description: '구독',
          frequency: 'MONTHLY',
          dayOfMonth: 15,
        )),
        expect: () => [
          RecurringLoaded(tTransactions,
              operationError: '반복 거래를 생성하지 못했습니다'),
        ],
      );
    });

    group('UpdateRecurringTransaction', () {
      final tUpdatedRent = RecurringTransaction(
        id: 'r1',
        type: 'EXPENSE',
        amount: 750000,
        description: '월세',
        frequency: 'MONTHLY',
        dayOfMonth: 25,
        nextRunDate: '2026-04-25',
        lastRunDate: '2026-03-25',
        isActive: true,
        categoryName: '월세',
        createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
      );

      blocTest<RecurringBloc, RecurringState>(
        'emits [Loaded] with updated transaction in list',
        build: () {
          when(mockRepository.updateRecurringTransaction(
            id: 'r1',
            amount: 750000,
          )).thenAnswer((_) async => Right(tUpdatedRent));
          return bloc;
        },
        seed: () => RecurringLoaded(tTransactions),
        act: (bloc) => bloc.add(const UpdateRecurringTransaction(
          id: 'r1',
          amount: 750000,
        )),
        expect: () => [
          RecurringLoaded([tUpdatedRent, tSalary]),
        ],
      );

      blocTest<RecurringBloc, RecurringState>(
        'emits [Loaded with operationError] on failure',
        build: () {
          when(mockRepository.updateRecurringTransaction(
            id: 'r1',
            amount: 750000,
          )).thenAnswer((_) async =>
              const Left(ServerFailure('반복 거래를 수정하지 못했습니다')));
          return bloc;
        },
        seed: () => RecurringLoaded(tTransactions),
        act: (bloc) => bloc.add(const UpdateRecurringTransaction(
          id: 'r1',
          amount: 750000,
        )),
        expect: () => [
          RecurringLoaded(tTransactions,
              operationError: '반복 거래를 수정하지 못했습니다'),
        ],
      );

      blocTest<RecurringBloc, RecurringState>(
        'toggles active status',
        build: () {
          final deactivated = RecurringTransaction(
            id: 'r1',
            type: 'EXPENSE',
            amount: 700000,
            description: '월세',
            frequency: 'MONTHLY',
            dayOfMonth: 25,
            nextRunDate: '2026-04-25',
            lastRunDate: '2026-03-25',
            isActive: false,
            categoryName: '월세',
            createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
          );
          when(mockRepository.updateRecurringTransaction(
            id: 'r1',
            isActive: false,
          )).thenAnswer((_) async => Right(deactivated));
          return bloc;
        },
        seed: () => RecurringLoaded(tTransactions),
        act: (bloc) => bloc.add(const UpdateRecurringTransaction(
          id: 'r1',
          isActive: false,
        )),
        expect: () => [
          isA<RecurringLoaded>().having(
            (s) => s.transactions.firstWhere((t) => t.id == 'r1').isActive,
            'r1 is inactive',
            false,
          ),
        ],
      );
    });

    group('DeleteRecurringTransaction', () {
      blocTest<RecurringBloc, RecurringState>(
        'emits [Loaded] with transaction removed',
        build: () {
          when(mockRepository.deleteRecurringTransaction('r1'))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () => RecurringLoaded(tTransactions),
        act: (bloc) => bloc.add(const DeleteRecurringTransaction('r1')),
        expect: () => [
          RecurringLoaded([tSalary]),
        ],
      );

      blocTest<RecurringBloc, RecurringState>(
        'emits [Loaded with operationError] on failure',
        build: () {
          when(mockRepository.deleteRecurringTransaction('r1')).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('반복 거래를 삭제하지 못했습니다')));
          return bloc;
        },
        seed: () => RecurringLoaded(tTransactions),
        act: (bloc) => bloc.add(const DeleteRecurringTransaction('r1')),
        expect: () => [
          RecurringLoaded(tTransactions,
              operationError: '반복 거래를 삭제하지 못했습니다'),
        ],
      );
    });
  });

  group('RecurringLoaded helpers', () {
    test('activeTransactions returns only active', () {
      final inactive = RecurringTransaction(
        id: 'r3',
        type: 'EXPENSE',
        amount: 5000,
        description: '비활성',
        frequency: 'DAILY',
        nextRunDate: '2026-03-20',
        isActive: false,
        createdAt: DateTime(2024),
      );
      final state = RecurringLoaded([...tTransactions, inactive]);
      expect(state.activeTransactions, tTransactions);
      expect(state.inactiveTransactions, [inactive]);
    });
  });

  group('RecurringTransaction entity', () {
    test('isExpense returns true for EXPENSE type', () {
      expect(tRent.isExpense, true);
      expect(tRent.isIncome, false);
    });

    test('isIncome returns true for INCOME type', () {
      expect(tSalary.isIncome, true);
      expect(tSalary.isExpense, false);
    });

    test('frequencyLabel returns Korean labels', () {
      expect(tRent.frequencyLabel, '매월');
    });
  });
}
