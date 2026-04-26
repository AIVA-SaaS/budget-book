import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/budget/domain/repositories/budget_repository.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';
import 'package:budget_book/core/error/failure.dart';

class MockBudgetRepository extends Mock implements BudgetRepository {
  @override
  Future<Either<Failure, List<Budget>>> getBudgets({
    required int year,
    required int month,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getBudgets, [], {#year: year, #month: month}),
        returnValue: Future.value(
          const Right<Failure, List<Budget>>([]),
        ),
      ) as Future<Either<Failure, List<Budget>>>;

  @override
  Future<Either<Failure, BudgetSummary>> getBudgetSummary({
    required int year,
    required int month,
  }) =>
      super.noSuchMethod(
        Invocation.method(
            #getBudgetSummary, [], {#year: year, #month: month}),
        returnValue: Future.value(
          const Right<Failure, BudgetSummary>(
            BudgetSummary(
              yearMonth: '2026-03',
              totalBudget: 0,
              totalSpent: 0,
              items: [],
            ),
          ),
        ),
      ) as Future<Either<Failure, BudgetSummary>>;

  @override
  Future<Either<Failure, Budget>> createBudget({
    String? categoryId,
    String? groupId,
    required String yearMonth,
    required int amount,
    String budgetPeriod = 'MONTHLY',
    int? weeklyAmount,
    String? pocketId,
    String periodType = 'MONTHLY',
    DateTime? startDate,
    DateTime? endDate,
    bool applyToFuture = false,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createBudget, [], {
          #categoryId: categoryId,
          #groupId: groupId,
          #yearMonth: yearMonth,
          #amount: amount,
          #budgetPeriod: budgetPeriod,
          #weeklyAmount: weeklyAmount,
          #pocketId: pocketId,
          #periodType: periodType,
          #startDate: startDate,
          #endDate: endDate,
          #applyToFuture: applyToFuture,
        }),
        returnValue: Future.value(
          Right<Failure, Budget>(_dummyBudget),
        ),
      ) as Future<Either<Failure, Budget>>;

  @override
  Future<Either<Failure, Budget>> updateBudget({
    required String id,
    required int amount,
    String? budgetPeriod,
    int? weeklyAmount,
    String? pocketId,
    String? periodType,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? groupId,
    String? yearMonth,
    bool applyToFuture = false,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateBudget, [], {
          #id: id,
          #amount: amount,
          #budgetPeriod: budgetPeriod,
          #weeklyAmount: weeklyAmount,
          #pocketId: pocketId,
          #periodType: periodType,
          #startDate: startDate,
          #endDate: endDate,
          #categoryId: categoryId,
          #groupId: groupId,
          #yearMonth: yearMonth,
          #applyToFuture: applyToFuture,
        }),
        returnValue: Future.value(
          Right<Failure, Budget>(_dummyBudget),
        ),
      ) as Future<Either<Failure, Budget>>;

  @override
  Future<Either<Failure, void>> deleteBudget(
    String? id, {
    bool applyToFuture = false,
  }) =>
      super.noSuchMethod(
        Invocation.method(#deleteBudget, [id], {
          #applyToFuture: applyToFuture,
        }),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, List<Budget>>> copyPreviousMonthBudgets({
    required int year,
    required int month,
  }) =>
      super.noSuchMethod(
        Invocation.method(
            #copyPreviousMonthBudgets, [], {#year: year, #month: month}),
        returnValue: Future.value(
          const Right<Failure, List<Budget>>([]),
        ),
      ) as Future<Either<Failure, List<Budget>>>;

  static final _dummyBudget = Budget(
    id: '',
    coupleId: '',
    yearMonth: '2026-03',
    amount: 0,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  late BudgetBloc budgetBloc;
  late MockBudgetRepository mockRepository;

  const tCategory = TransactionCategory(
    id: 'cat-1',
    name: '식비',
    type: 'EXPENSE',
    icon: 'restaurant',
    color: '#FF5733',
  );

  final tBudget1 = Budget(
    id: 'budget-1',
    coupleId: 'couple-1',
    category: tCategory,
    yearMonth: '2026-03',
    amount: 150000,
    createdAt: DateTime.parse('2026-03-01T12:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T12:00:00Z'),
  );

  final tBudget2 = Budget(
    id: 'budget-2',
    coupleId: 'couple-1',
    category: null,
    yearMonth: '2026-03',
    amount: 3000000,
    createdAt: DateTime.parse('2026-03-01T12:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T12:00:00Z'),
  );

  final tBudgets = [tBudget1, tBudget2];

  const tSummary = BudgetSummary(
    yearMonth: '2026-03',
    totalBudget: 3150000,
    totalSpent: 1800000,
    items: [
      BudgetSummaryItem(
        category: tCategory,
        budgetAmount: 150000,
        spentAmount: 95000,
        remainingAmount: 55000,
        usageRate: 63.3,
      ),
      BudgetSummaryItem(
        category: null,
        budgetAmount: 3000000,
        spentAmount: 1705000,
        remainingAmount: 1295000,
        usageRate: 56.8,
      ),
    ],
  );

  setUp(() {
    mockRepository = MockBudgetRepository();
    budgetBloc = BudgetBloc(budgetRepository: mockRepository);
  });

  tearDown(() {
    budgetBloc.close();
  });

  group('BudgetBloc', () {
    test('initial state is BudgetInitial', () {
      expect(budgetBloc.state, const BudgetInitial());
    });

    group('LoadBudgets', () {
      blocTest<BudgetBloc, BudgetState>(
        'emits [BudgetLoading, BudgetLoaded] on success with summary',
        build: () {
          when(mockRepository.getBudgets(year: 2026, month: 3))
              .thenAnswer((_) async => Right(tBudgets));
          when(mockRepository.getBudgetSummary(year: 2026, month: 3))
              .thenAnswer((_) async => const Right(tSummary));
          return budgetBloc;
        },
        act: (bloc) => bloc.add(const LoadBudgets(year: 2026, month: 3)),
        expect: () => [
          const BudgetLoading(),
          BudgetLoaded(
            budgets: tBudgets,
            summary: tSummary,
            year: 2026,
            month: 3,
          ),
        ],
      );

      blocTest<BudgetBloc, BudgetState>(
        'emits [BudgetLoading, BudgetError] on budgets failure',
        build: () {
          when(mockRepository.getBudgets(year: 2026, month: 3))
              .thenAnswer((_) async =>
                  const Left(ServerFailure('Failed to load budgets')));
          when(mockRepository.getBudgetSummary(year: 2026, month: 3))
              .thenAnswer((_) async => const Right(tSummary));
          return budgetBloc;
        },
        act: (bloc) => bloc.add(const LoadBudgets(year: 2026, month: 3)),
        expect: () => [
          const BudgetLoading(),
          const BudgetError('Failed to load budgets'),
        ],
      );

      blocTest<BudgetBloc, BudgetState>(
        'emits BudgetLoaded without summary when summary fails',
        build: () {
          when(mockRepository.getBudgets(year: 2026, month: 3))
              .thenAnswer((_) async => Right(tBudgets));
          when(mockRepository.getBudgetSummary(year: 2026, month: 3))
              .thenAnswer((_) async =>
                  const Left(ServerFailure('Failed to load summary')));
          return budgetBloc;
        },
        act: (bloc) => bloc.add(const LoadBudgets(year: 2026, month: 3)),
        expect: () => [
          const BudgetLoading(),
          BudgetLoaded(
            budgets: tBudgets,
            year: 2026,
            month: 3,
          ),
        ],
      );
    });

    group('CreateBudget', () {
      blocTest<BudgetBloc, BudgetState>(
        'emits BudgetLoaded with operationError on failure',
        build: () {
          when(mockRepository.createBudget(
            categoryId: 'cat-1',
            yearMonth: '2026-03',
            amount: 150000,
            budgetPeriod: 'MONTHLY',
            weeklyAmount: null,
            pocketId: null,
            periodType: 'MONTHLY',
            startDate: null,
            endDate: null,
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Duplicate budget')));
          return budgetBloc;
        },
        seed: () => BudgetLoaded(
          budgets: tBudgets,
          summary: tSummary,
          year: 2026,
          month: 3,
        ),
        act: (bloc) => bloc.add(const CreateBudget(
          categoryId: 'cat-1',
          yearMonth: '2026-03',
          amount: 150000,
        )),
        expect: () => [
          BudgetLoaded(
            budgets: tBudgets,
            summary: tSummary,
            year: 2026,
            month: 3,
            operationError: 'Duplicate budget',
          ),
        ],
      );

      blocTest<BudgetBloc, BudgetState>(
        'reloads budgets on create success',
        build: () {
          when(mockRepository.createBudget(
            categoryId: null,
            yearMonth: '2026-03',
            amount: 3000000,
            budgetPeriod: 'MONTHLY',
            weeklyAmount: null,
            pocketId: null,
            periodType: 'MONTHLY',
            startDate: null,
            endDate: null,
          )).thenAnswer((_) async => Right(tBudget2));
          when(mockRepository.getBudgets(year: 2026, month: 3))
              .thenAnswer((_) async => Right(tBudgets));
          when(mockRepository.getBudgetSummary(year: 2026, month: 3))
              .thenAnswer((_) async => const Right(tSummary));
          return budgetBloc;
        },
        seed: () => const BudgetLoaded(
          budgets: [],
          year: 2026,
          month: 3,
        ),
        act: (bloc) {
          // Set year/month first
          bloc.add(const LoadBudgets(year: 2026, month: 3));
        },
        skip: 2, // skip Loading + Loaded from LoadBudgets
        verify: (_) {
          verify(mockRepository.getBudgets(year: 2026, month: 3)).called(1);
        },
      );
    });

    group('UpdateBudget', () {
      blocTest<BudgetBloc, BudgetState>(
        'emits BudgetLoaded with operationError on failure',
        build: () {
          when(mockRepository.updateBudget(
            id: 'budget-1',
            amount: 200000,
            budgetPeriod: null,
            weeklyAmount: null,
            pocketId: null,
            periodType: null,
            startDate: null,
            endDate: null,
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to update budget')));
          return budgetBloc;
        },
        seed: () => BudgetLoaded(
          budgets: tBudgets,
          summary: tSummary,
          year: 2026,
          month: 3,
        ),
        act: (bloc) => bloc.add(const UpdateBudget(
          id: 'budget-1',
          amount: 200000,
        )),
        expect: () => [
          BudgetLoaded(
            budgets: tBudgets,
            summary: tSummary,
            year: 2026,
            month: 3,
            operationError: 'Failed to update budget',
          ),
        ],
      );
    });

    group('DeleteBudget', () {
      blocTest<BudgetBloc, BudgetState>(
        'removes budget from list on success and reloads',
        build: () {
          when(mockRepository.deleteBudget('budget-1'))
              .thenAnswer((_) async => const Right(null));
          when(mockRepository.getBudgets(year: 2026, month: 3))
              .thenAnswer((_) async => Right([tBudget2]));
          when(mockRepository.getBudgetSummary(year: 2026, month: 3))
              .thenAnswer((_) async => const Right(tSummary));
          return budgetBloc;
        },
        seed: () => BudgetLoaded(
          budgets: tBudgets,
          summary: tSummary,
          year: 2026,
          month: 3,
        ),
        act: (bloc) {
          // Set year/month first then delete
          bloc.add(const LoadBudgets(year: 2026, month: 3));
        },
        skip: 2,
        verify: (_) {
          verify(mockRepository.getBudgets(year: 2026, month: 3)).called(1);
        },
      );

      blocTest<BudgetBloc, BudgetState>(
        'emits BudgetLoaded with operationError on delete failure',
        build: () {
          when(mockRepository.deleteBudget('budget-1')).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('Failed to delete budget')));
          return budgetBloc;
        },
        seed: () => BudgetLoaded(
          budgets: tBudgets,
          summary: tSummary,
          year: 2026,
          month: 3,
        ),
        act: (bloc) => bloc.add(const DeleteBudget('budget-1')),
        expect: () => [
          BudgetLoaded(
            budgets: tBudgets,
            summary: tSummary,
            year: 2026,
            month: 3,
            operationError: 'Failed to delete budget',
          ),
        ],
      );

      // Phase 25 후속 C-3 — applyToFuture 가 repository 까지 전달되는지 검증
      blocTest<BudgetBloc, BudgetState>(
        'forwards applyToFuture=true to repository.deleteBudget',
        build: () {
          when(mockRepository.deleteBudget('budget-1',
                  applyToFuture: true))
              .thenAnswer((_) async => const Right(null));
          when(mockRepository.getBudgets(year: 2026, month: 3))
              .thenAnswer((_) async => Right([tBudget2]));
          when(mockRepository.getBudgetSummary(year: 2026, month: 3))
              .thenAnswer((_) async => const Right(tSummary));
          return budgetBloc;
        },
        seed: () => BudgetLoaded(
          budgets: tBudgets,
          summary: tSummary,
          year: 2026,
          month: 3,
        ),
        act: (bloc) => bloc.add(
          const DeleteBudget('budget-1', applyToFuture: true),
        ),
        verify: (_) {
          verify(mockRepository.deleteBudget('budget-1',
                  applyToFuture: true))
              .called(1);
        },
      );
    });

    // Phase 25 후속 C-3 — UpdateBudget 에 applyToFuture 가 repository 까지 전달
    group('UpdateBudget with applyToFuture', () {
      blocTest<BudgetBloc, BudgetState>(
        'forwards applyToFuture=true to repository.updateBudget',
        build: () {
          when(mockRepository.updateBudget(
            id: 'budget-1',
            amount: 200000,
            budgetPeriod: null,
            weeklyAmount: null,
            pocketId: null,
            periodType: null,
            startDate: null,
            endDate: null,
            applyToFuture: true,
          )).thenAnswer((_) async => Right(tBudget1));
          when(mockRepository.getBudgets(year: 2026, month: 3))
              .thenAnswer((_) async => Right(tBudgets));
          when(mockRepository.getBudgetSummary(year: 2026, month: 3))
              .thenAnswer((_) async => const Right(tSummary));
          return budgetBloc;
        },
        seed: () => BudgetLoaded(
          budgets: tBudgets,
          summary: tSummary,
          year: 2026,
          month: 3,
        ),
        act: (bloc) => bloc.add(const UpdateBudget(
          id: 'budget-1',
          amount: 200000,
          applyToFuture: true,
        )),
        verify: (_) {
          verify(mockRepository.updateBudget(
            id: 'budget-1',
            amount: 200000,
            budgetPeriod: null,
            weeklyAmount: null,
            pocketId: null,
            periodType: null,
            startDate: null,
            endDate: null,
            applyToFuture: true,
          )).called(1);
        },
      );
    });

    group('CopyPreviousMonthBudgets', () {
      blocTest<BudgetBloc, BudgetState>(
        'emits BudgetLoaded with operationSuccess on success, then reloads',
        build: () {
          when(mockRepository.copyPreviousMonthBudgets(
            year: 2026,
            month: 3,
          )).thenAnswer((_) async => Right(tBudgets));
          when(mockRepository.getBudgets(year: 2026, month: 3))
              .thenAnswer((_) async => Right(tBudgets));
          when(mockRepository.getBudgetSummary(year: 2026, month: 3))
              .thenAnswer((_) async => const Right(tSummary));
          return budgetBloc;
        },
        seed: () => const BudgetLoaded(
          budgets: [],
          summary: tSummary,
          year: 2026,
          month: 3,
        ),
        act: (bloc) {
          // Set year/month
          bloc.add(const LoadBudgets(year: 2026, month: 3));
        },
        skip: 2, // skip Loading + Loaded from LoadBudgets
        verify: (_) {
          verify(mockRepository.getBudgets(year: 2026, month: 3)).called(1);
        },
      );

      blocTest<BudgetBloc, BudgetState>(
        'emits BudgetLoaded with operationError on failure',
        build: () {
          when(mockRepository.copyPreviousMonthBudgets(
            year: 2026,
            month: 3,
          )).thenAnswer((_) async =>
              const Left(ServerFailure('No budgets found for previous month')));
          return budgetBloc;
        },
        seed: () => BudgetLoaded(
          budgets: tBudgets,
          summary: tSummary,
          year: 2026,
          month: 3,
        ),
        act: (bloc) => bloc.add(
            const CopyPreviousMonthBudgets(year: 2026, month: 3)),
        expect: () => [
          BudgetLoaded(
            budgets: tBudgets,
            summary: tSummary,
            year: 2026,
            month: 3,
            operationError: 'No budgets found for previous month',
          ),
        ],
      );
    });
  });

  group('BudgetSummary', () {
    test('remainingAmount is totalBudget minus totalSpent', () {
      expect(tSummary.remainingAmount, 1350000);
    });

    test('usageRate calculates correctly', () {
      expect(tSummary.usageRate, closeTo(57.14, 0.01));
    });

    test('isOverBudget returns false when under budget', () {
      expect(tSummary.isOverBudget, false);
    });

    test('isOverBudget returns true when over budget', () {
      const overSummary = BudgetSummary(
        yearMonth: '2026-03',
        totalBudget: 100000,
        totalSpent: 150000,
        items: [],
      );
      expect(overSummary.isOverBudget, true);
    });
  });

  group('BudgetLoaded', () {
    test('totalBudget returns summary totalBudget', () {
      final state = BudgetLoaded(
        budgets: tBudgets,
        summary: tSummary,
        year: 2026,
        month: 3,
      );
      expect(state.totalBudget, 3150000);
    });

    test('totalSpent returns summary totalSpent', () {
      final state = BudgetLoaded(
        budgets: tBudgets,
        summary: tSummary,
        year: 2026,
        month: 3,
      );
      expect(state.totalSpent, 1800000);
    });

    test('totalBudget returns 0 when no summary', () {
      final state = BudgetLoaded(
        budgets: tBudgets,
        year: 2026,
        month: 3,
      );
      expect(state.totalBudget, 0);
    });
  });
}
