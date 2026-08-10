import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/domain/repositories/budget_repository.dart';
import 'package:budget_book/features/home/domain/entities/dashboard_widget_config.dart';
import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';
import 'package:budget_book/features/reconciliation/domain/repositories/reconciliation_repository.dart';

class MockStatisticsRepository extends Mock implements StatisticsRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockBudgetRepository extends Mock implements BudgetRepository {}

class MockReconciliationRepository extends Mock
    implements ReconciliationRepository {}

void main() {
  late MockStatisticsRepository mockStatisticsRepo;
  late MockTransactionRepository mockTransactionRepo;
  late MockBudgetRepository mockBudgetRepo;
  late MockReconciliationRepository mockReconciliationRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockStatisticsRepo = MockStatisticsRepository();
    mockTransactionRepo = MockTransactionRepository();
    mockBudgetRepo = MockBudgetRepository();
    mockReconciliationRepo = MockReconciliationRepository();
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

  const testReconciliationSummary = ReconciliationSummary(
    yearMonth: '2026-03',
    snapshotCount: 1,
    recordedCount: 4,
    unrecordedCount: 7,
    unrecordedIncome: 100000,
    unrecordedExpense: 250000,
    unrecordedTransfer: 0,
    needsReviewCount: 2,
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
        when(() => mockStatisticsRepo.getPaymentMethodStats(
              year: 2026, month: 3))
            .thenAnswer(
                (_) async => const Right(<PaymentMethodStatistics>[]));
        when(() => mockStatisticsRepo.getMonthlyTrend(months: 6))
            .thenAnswer((_) async => const Right([]));
        when(() => mockStatisticsRepo.getCategoryBreakdown(
              year: 2026, month: 3, type: 'EXPENSE'))
            .thenAnswer((_) async => const Right([]));
        return DashboardBloc(
          statisticsRepository: mockStatisticsRepo,
          transactionRepository: mockTransactionRepo,
          budgetRepository: mockBudgetRepo,
          reconciliationRepository: mockReconciliationRepo,
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
        when(() => mockStatisticsRepo.getPaymentMethodStats(
              year: 2026, month: 3))
            .thenAnswer(
                (_) async => const Left(ServerFailure('pm stats error')));
        when(() => mockStatisticsRepo.getMonthlyTrend(months: 6))
            .thenAnswer((_) async => const Left(ServerFailure('trend error')));
        when(() => mockStatisticsRepo.getCategoryBreakdown(
              year: 2026, month: 3, type: 'EXPENSE'))
            .thenAnswer((_) async => const Left(ServerFailure('cat error')));
        return DashboardBloc(
          statisticsRepository: mockStatisticsRepo,
          transactionRepository: mockTransactionRepo,
          budgetRepository: mockBudgetRepo,
          reconciliationRepository: mockReconciliationRepo,
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
      'loads all six APIs in parallel (Future.wait)',
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
        when(() => mockStatisticsRepo.getPaymentMethodStats(
              year: 2026, month: 3))
            .thenAnswer(
                (_) async => const Right(<PaymentMethodStatistics>[]));
        when(() => mockStatisticsRepo.getMonthlyTrend(months: 6))
            .thenAnswer((_) async => const Right([]));
        when(() => mockStatisticsRepo.getCategoryBreakdown(
              year: 2026, month: 3, type: 'EXPENSE'))
            .thenAnswer((_) async => const Right([]));
        return DashboardBloc(
          statisticsRepository: mockStatisticsRepo,
          transactionRepository: mockTransactionRepo,
          budgetRepository: mockBudgetRepo,
          reconciliationRepository: mockReconciliationRepo,
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
        verify(() => mockStatisticsRepo.getPaymentMethodStats(
              year: 2026, month: 3))
            .called(1);
        verify(() => mockStatisticsRepo.getMonthlyTrend(months: 6))
            .called(1);
        verify(() => mockStatisticsRepo.getCategoryBreakdown(
              year: 2026, month: 3, type: 'EXPENSE'))
            .called(1);
      },
    );
    // ---- 월말 점검 위젯 (2026-08-10) ----
    //
    // 정산 요약은 "위젯이 켜져 있을 때만" 조회한다. 기본 OFF 이므로 켜지 않은
    // 사용자에게는 요청이 하나도 늘지 않아야 한다.

    void stubEveryoneElse() {
      when(() => mockStatisticsRepo.getSummary(year: 2026, month: 3))
          .thenAnswer((_) async => const Right(testSummary));
      when(() => mockTransactionRepo.getTransactions(
            year: 2026,
            month: 3,
            size: 5,
          )).thenAnswer((_) async => Right(testPageResponse));
      when(() => mockBudgetRepo.getBudgetSummary(year: 2026, month: 3))
          .thenAnswer((_) async => const Right(testBudgetSummary));
      when(() => mockStatisticsRepo.getPaymentMethodStats(year: 2026, month: 3))
          .thenAnswer((_) async => const Right(<PaymentMethodStatistics>[]));
      when(() => mockStatisticsRepo.getMonthlyTrend(months: 6))
          .thenAnswer((_) async => const Right([]));
      when(() => mockStatisticsRepo.getCategoryBreakdown(
            year: 2026, month: 3, type: 'EXPENSE'))
          .thenAnswer((_) async => const Right([]));
    }

    /// Persists a widget config with only the month-end review card enabled.
    /// The storage key mirrors HomeConfigService's private `_key`.
    void enableReconciliationWidget() {
      SharedPreferences.setMockInitialValues({
        'dashboard_widget_config': jsonEncode(
          defaultDashboardWidgets
              .map((w) =>
                  w.copyWith(enabled: w.id == kReconciliationWidgetId).toJson())
              .toList(),
        ),
      });
    }

    blocTest<DashboardBloc, DashboardState>(
      'skips the reconciliation summary call while the widget is off (default)',
      build: () {
        stubEveryoneElse();
        return DashboardBloc(
          statisticsRepository: mockStatisticsRepo,
          transactionRepository: mockTransactionRepo,
          budgetRepository: mockBudgetRepo,
          reconciliationRepository: mockReconciliationRepo,
        );
      },
      act: (bloc) => bloc.add(const LoadDashboard(year: 2026, month: 3)),
      verify: (_) {
        verifyNever(
            () => mockReconciliationRepo.getSummary(year: 2026, month: 3));
      },
      expect: () => [
        const DashboardLoading(),
        isA<DashboardLoaded>().having(
            (s) => s.reconciliationSummary, 'reconciliationSummary', isNull),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'loads the reconciliation summary when the widget is enabled',
      build: () {
        enableReconciliationWidget();
        stubEveryoneElse();
        when(() => mockReconciliationRepo.getSummary(year: 2026, month: 3))
            .thenAnswer((_) async => const Right(testReconciliationSummary));
        return DashboardBloc(
          statisticsRepository: mockStatisticsRepo,
          transactionRepository: mockTransactionRepo,
          budgetRepository: mockBudgetRepo,
          reconciliationRepository: mockReconciliationRepo,
        );
      },
      act: (bloc) => bloc.add(const LoadDashboard(year: 2026, month: 3)),
      verify: (_) {
        verify(() => mockReconciliationRepo.getSummary(year: 2026, month: 3))
            .called(1);
      },
      expect: () => [
        const DashboardLoading(),
        isA<DashboardLoaded>().having((s) => s.reconciliationSummary,
            'reconciliationSummary', testReconciliationSummary),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'keeps the rest of the dashboard when the summary call fails',
      build: () {
        enableReconciliationWidget();
        stubEveryoneElse();
        when(() => mockReconciliationRepo.getSummary(year: 2026, month: 3))
            .thenAnswer((_) async => const Left(ServerFailure('recon error')));
        return DashboardBloc(
          statisticsRepository: mockStatisticsRepo,
          transactionRepository: mockTransactionRepo,
          budgetRepository: mockBudgetRepo,
          reconciliationRepository: mockReconciliationRepo,
        );
      },
      act: (bloc) => bloc.add(const LoadDashboard(year: 2026, month: 3)),
      expect: () => [
        const DashboardLoading(),
        isA<DashboardLoaded>()
            .having((s) => s.summary, 'summary', testSummary)
            .having((s) => s.reconciliationSummary, 'reconciliationSummary',
                isNull),
      ],
    );
  });
}
