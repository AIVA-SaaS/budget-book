import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/domain/repositories/budget_repository.dart';

class MockStatisticsRepository extends Mock implements StatisticsRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockBudgetRepository extends Mock implements BudgetRepository {}

void main() {
  late MockStatisticsRepository mockStatisticsRepo;
  late MockTransactionRepository mockTransactionRepo;
  late MockBudgetRepository mockBudgetRepo;

  setUp(() {
    mockStatisticsRepo = MockStatisticsRepository();
    mockTransactionRepo = MockTransactionRepository();
    mockBudgetRepo = MockBudgetRepository();
  });

  const testSummary = StatisticsSummary(
    yearMonth: '2026-03',
    totalIncome: 5000000,
    totalExpense: 3200000,
    balance: 1800000,
    transactionCount: 45,
  );

  final testTransactions = [
    Transaction(
      id: 'txn-1',
      coupleId: 'couple-1',
      author: const TransactionAuthor(id: 'user-1', nickname: 'Test'),
      type: 'EXPENSE',
      amount: 15000,
      description: '점심 식사',
      transactionDate: '2026-03-12',
      createdAt: DateTime(2026, 3, 12),
      updatedAt: DateTime(2026, 3, 12),
    ),
  ];

  final testPageResponse = PageResponse<Transaction>(
    content: testTransactions,
    page: 0,
    size: 5,
    totalElements: 1,
    totalPages: 1,
    first: true,
    last: true,
  );

  const testBudgetSummary = BudgetSummary(
    yearMonth: '2026-03',
    totalBudget: 5000000,
    totalSpent: 3200000,
    items: [],
  );

  group('DashboardBloc', () {
    blocTest<DashboardBloc, DashboardState>(
      'emits [DashboardLoading, DashboardLoaded] when LoadDashboard succeeds',
      build: () {
        when(() => mockStatisticsRepo.getSummary(year: 2026, month: 3))
            .thenAnswer((_) async => const Right(testSummary));
        when(() => mockTransactionRepo.getTransactions(
              year: 2026,
              month: 3,
              size: 5,
            )).thenAnswer((_) async => Right(testPageResponse));
        when(() => mockBudgetRepo.getBudgetSummary(year: 2026, month: 3))
            .thenAnswer((_) async => const Right(testBudgetSummary));
        return DashboardBloc(
          statisticsRepository: mockStatisticsRepo,
          transactionRepository: mockTransactionRepo,
          budgetRepository: mockBudgetRepo,
        );
      },
      act: (bloc) =>
          bloc.add(const LoadDashboard(year: 2026, month: 3)),
      expect: () => [
        const DashboardLoading(),
        isA<DashboardLoaded>()
            .having((s) => s.summary, 'summary', testSummary)
            .having((s) => s.recentTransactions, 'transactions',
                testTransactions)
            .having(
                (s) => s.budgetSummary, 'budgetSummary', testBudgetSummary),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits DashboardLoaded with errors when APIs fail',
      build: () {
        when(() => mockStatisticsRepo.getSummary(year: 2026, month: 3))
            .thenAnswer((_) async =>
                const Left(ServerFailure('summary error')));
        when(() => mockTransactionRepo.getTransactions(
              year: 2026,
              month: 3,
              size: 5,
            )).thenAnswer(
                (_) async => const Left(ServerFailure('transaction error')));
        when(() => mockBudgetRepo.getBudgetSummary(year: 2026, month: 3))
            .thenAnswer(
                (_) async => const Left(ServerFailure('budget error')));
        return DashboardBloc(
          statisticsRepository: mockStatisticsRepo,
          transactionRepository: mockTransactionRepo,
          budgetRepository: mockBudgetRepo,
        );
      },
      act: (bloc) =>
          bloc.add(const LoadDashboard(year: 2026, month: 3)),
      expect: () => [
        const DashboardLoading(),
        isA<DashboardLoaded>()
            .having((s) => s.summaryError, 'summaryError', 'summary error')
            .having((s) => s.transactionsError, 'transactionsError',
                'transaction error')
            .having(
                (s) => s.budgetError, 'budgetError', 'budget error'),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'loads all three APIs in parallel (Future.wait)',
      build: () {
        when(() => mockStatisticsRepo.getSummary(year: 2026, month: 3))
            .thenAnswer((_) async => const Right(testSummary));
        when(() => mockTransactionRepo.getTransactions(
              year: 2026,
              month: 3,
              size: 5,
            )).thenAnswer((_) async => Right(testPageResponse));
        when(() => mockBudgetRepo.getBudgetSummary(year: 2026, month: 3))
            .thenAnswer((_) async => const Right(testBudgetSummary));
        return DashboardBloc(
          statisticsRepository: mockStatisticsRepo,
          transactionRepository: mockTransactionRepo,
          budgetRepository: mockBudgetRepo,
        );
      },
      act: (bloc) =>
          bloc.add(const LoadDashboard(year: 2026, month: 3)),
      verify: (_) {
        verify(() => mockStatisticsRepo.getSummary(year: 2026, month: 3))
            .called(1);
        verify(() => mockTransactionRepo.getTransactions(
              year: 2026,
              month: 3,
              size: 5,
            )).called(1);
        verify(() =>
                mockBudgetRepo.getBudgetSummary(year: 2026, month: 3))
            .called(1);
      },
    );
  });
}
