import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';

class MockStatisticsRepository extends Mock implements StatisticsRepository {}

void main() {
  late MockStatisticsRepository mockRepository;

  setUp(() {
    mockRepository = MockStatisticsRepository();
  });

  const testSummary = StatisticsSummary(
    yearMonth: '2026-03',
    totalIncome: 5000000,
    totalExpense: 3200000,
    balance: 1800000,
    transactionCount: 45,
  );

  const testPrevYearSummary = StatisticsSummary(
    yearMonth: '2025-03',
    totalIncome: 4200000,
    totalExpense: 2800000,
    balance: 1400000,
    transactionCount: 38,
  );

  final testCategoryStats = [
    const CategoryStatistics(
      category: TransactionCategory(
        id: '1',
        name: '식비',
        type: 'EXPENSE',
        icon: 'restaurant',
        color: '#FF5733',
      ),
      amount: 800000,
      percentage: 25.0,
      transactionCount: 12,
    ),
    const CategoryStatistics(
      category: TransactionCategory(
        id: '2',
        name: '교통비',
        type: 'EXPENSE',
        icon: 'directions_car',
        color: '#2196F3',
      ),
      amount: 320000,
      percentage: 10.0,
      transactionCount: 8,
    ),
  ];

  final testTrends = [
    const MonthlyTrend(
      yearMonth: '2025-10',
      totalIncome: 4500000,
      totalExpense: 3100000,
      balance: 1400000,
    ),
    const MonthlyTrend(
      yearMonth: '2025-11',
      totalIncome: 4800000,
      totalExpense: 3400000,
      balance: 1400000,
    ),
    const MonthlyTrend(
      yearMonth: '2026-03',
      totalIncome: 5000000,
      totalExpense: 3200000,
      balance: 1800000,
    ),
  ];

  group('StatisticsBloc', () {
    blocTest<StatisticsBloc, StatisticsState>(
      'emits loading then loaded states when LoadAllStatistics succeeds',
      build: () {
        when(() => mockRepository.getSummary(year: 2026, month: 3))
            .thenAnswer((_) async => const Right(testSummary));
        when(() => mockRepository.getCategoryBreakdown(
              year: 2026,
              month: 3,
              type: 'EXPENSE',
            )).thenAnswer((_) async => Right(testCategoryStats));
        when(() => mockRepository.getMonthlyTrend(months: 6))
            .thenAnswer((_) async => Right(testTrends));
        return StatisticsBloc(statisticsRepository: mockRepository);
      },
      act: (bloc) =>
          bloc.add(const LoadAllStatistics(year: 2026, month: 3)),
      verify: (bloc) {
        expect(bloc.state.summary, testSummary);
        expect(bloc.state.categoryStats, testCategoryStats);
        expect(bloc.state.trends, testTrends);
        expect(bloc.state.summaryLoading, false);
        expect(bloc.state.categoryLoading, false);
        expect(bloc.state.trendLoading, false);
      },
    );

    blocTest<StatisticsBloc, StatisticsState>(
      'emits error state when LoadSummary fails',
      build: () {
        when(() => mockRepository.getSummary(year: 2026, month: 3))
            .thenAnswer((_) async =>
                const Left(ServerFailure('통계 요약을 불러오지 못했습니다')));
        return StatisticsBloc(statisticsRepository: mockRepository);
      },
      act: (bloc) =>
          bloc.add(const LoadSummary(year: 2026, month: 3)),
      verify: (bloc) {
        expect(bloc.state.summaryError, '통계 요약을 불러오지 못했습니다');
        expect(bloc.state.summaryLoading, false);
      },
    );

    blocTest<StatisticsBloc, StatisticsState>(
      'emits loaded category stats when LoadCategoryBreakdown succeeds',
      build: () {
        when(() => mockRepository.getCategoryBreakdown(
              year: 2026,
              month: 3,
              type: 'INCOME',
            )).thenAnswer((_) async => Right(testCategoryStats));
        return StatisticsBloc(statisticsRepository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadCategoryBreakdown(
          year: 2026, month: 3, type: 'INCOME')),
      verify: (bloc) {
        expect(bloc.state.categoryStats, testCategoryStats);
        expect(bloc.state.categoryType, 'INCOME');
        expect(bloc.state.categoryLoading, false);
      },
    );

    blocTest<StatisticsBloc, StatisticsState>(
      'emits loaded trends when LoadMonthlyTrend succeeds',
      build: () {
        when(() => mockRepository.getMonthlyTrend(months: 6))
            .thenAnswer((_) async => Right(testTrends));
        return StatisticsBloc(statisticsRepository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadMonthlyTrend()),
      verify: (bloc) {
        expect(bloc.state.trends, testTrends);
        expect(bloc.state.trendLoading, false);
      },
    );

    blocTest<StatisticsBloc, StatisticsState>(
      'emits error when LoadCategoryBreakdown fails',
      build: () {
        when(() => mockRepository.getCategoryBreakdown(
              year: 2026,
              month: 3,
              type: 'EXPENSE',
            )).thenAnswer((_) async =>
                const Left(ServerFailure('카테고리별 통계를 불러오지 못했습니다')));
        return StatisticsBloc(statisticsRepository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadCategoryBreakdown(
          year: 2026, month: 3)),
      verify: (bloc) {
        expect(bloc.state.categoryError, '카테고리별 통계를 불러오지 못했습니다');
        expect(bloc.state.categoryLoading, false);
      },
    );

    blocTest<StatisticsBloc, StatisticsState>(
      'emits error when LoadMonthlyTrend fails',
      build: () {
        when(() => mockRepository.getMonthlyTrend(months: 6))
            .thenAnswer((_) async =>
                const Left(ServerFailure('월별 추이를 불러오지 못했습니다')));
        return StatisticsBloc(statisticsRepository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadMonthlyTrend()),
      verify: (bloc) {
        expect(bloc.state.trendError, '월별 추이를 불러오지 못했습니다');
        expect(bloc.state.trendLoading, false);
      },
    );

    group('LoadYearComparison', () {
      blocTest<StatisticsBloc, StatisticsState>(
        'emits comparison data when both years succeed',
        build: () {
          when(() => mockRepository.getSummary(year: 2026, month: 3))
              .thenAnswer((_) async => const Right(testSummary));
          when(() => mockRepository.getSummary(year: 2025, month: 3))
              .thenAnswer((_) async => const Right(testPrevYearSummary));
          return StatisticsBloc(statisticsRepository: mockRepository);
        },
        act: (bloc) =>
            bloc.add(const LoadYearComparison(year: 2026, month: 3)),
        verify: (bloc) {
          expect(bloc.state.comparisonLoading, false);
          expect(bloc.state.currentYearSummary, testSummary);
          expect(bloc.state.previousYearSummary, testPrevYearSummary);
          expect(bloc.state.comparisonError, null);
        },
      );

      blocTest<StatisticsBloc, StatisticsState>(
        'handles previous year failure gracefully',
        build: () {
          when(() => mockRepository.getSummary(year: 2026, month: 3))
              .thenAnswer((_) async => const Right(testSummary));
          when(() => mockRepository.getSummary(year: 2025, month: 3))
              .thenAnswer((_) async =>
                  const Left(ServerFailure('No data')));
          return StatisticsBloc(statisticsRepository: mockRepository);
        },
        act: (bloc) =>
            bloc.add(const LoadYearComparison(year: 2026, month: 3)),
        verify: (bloc) {
          expect(bloc.state.comparisonLoading, false);
          expect(bloc.state.currentYearSummary, testSummary);
          expect(bloc.state.previousYearSummary, null);
          expect(bloc.state.comparisonError, null);
        },
      );

      blocTest<StatisticsBloc, StatisticsState>(
        'emits error when current year fails',
        build: () {
          when(() => mockRepository.getSummary(year: 2026, month: 3))
              .thenAnswer((_) async =>
                  const Left(ServerFailure('통계 요약을 불러오지 못했습니다')));
          when(() => mockRepository.getSummary(year: 2025, month: 3))
              .thenAnswer((_) async => const Right(testPrevYearSummary));
          return StatisticsBloc(statisticsRepository: mockRepository);
        },
        act: (bloc) =>
            bloc.add(const LoadYearComparison(year: 2026, month: 3)),
        verify: (bloc) {
          expect(bloc.state.comparisonLoading, false);
          expect(bloc.state.comparisonError, '통계 요약을 불러오지 못했습니다');
        },
      );
    });

    group('LoadPaymentMethodStats', () {
      const testPaymentMethodStats = [
        PaymentMethodStatistics(
          paymentMethodId: 'pm-1',
          paymentMethodName: '신한카드',
          paymentMethodType: 'CREDIT_CARD',
          totalAmount: 1500000,
          transactionCount: 20,
          percentage: 46.9,
        ),
        PaymentMethodStatistics(
          paymentMethodId: 'pm-2',
          paymentMethodName: '현금',
          paymentMethodType: 'CASH',
          totalAmount: 800000,
          transactionCount: 15,
          percentage: 25.0,
        ),
      ];

      blocTest<StatisticsBloc, StatisticsState>(
        'emits loaded payment method stats on success',
        build: () {
          when(() => mockRepository.getPaymentMethodStats(
                year: 2026,
                month: 3,
              )).thenAnswer((_) async => const Right(testPaymentMethodStats));
          return StatisticsBloc(statisticsRepository: mockRepository);
        },
        act: (bloc) =>
            bloc.add(const LoadPaymentMethodStats(year: 2026, month: 3)),
        verify: (bloc) {
          expect(bloc.state.paymentMethodStats, testPaymentMethodStats);
          expect(bloc.state.paymentMethodLoading, false);
          expect(bloc.state.paymentMethodError, null);
        },
      );

      blocTest<StatisticsBloc, StatisticsState>(
        'emits error when LoadPaymentMethodStats fails',
        build: () {
          when(() => mockRepository.getPaymentMethodStats(
                year: 2026,
                month: 3,
              )).thenAnswer((_) async =>
              const Left(ServerFailure('결제수단별 통계를 불러오지 못했습니다')));
          return StatisticsBloc(statisticsRepository: mockRepository);
        },
        act: (bloc) =>
            bloc.add(const LoadPaymentMethodStats(year: 2026, month: 3)),
        verify: (bloc) {
          expect(
              bloc.state.paymentMethodError, '결제수단별 통계를 불러오지 못했습니다');
          expect(bloc.state.paymentMethodLoading, false);
        },
      );
    });
  });
}
