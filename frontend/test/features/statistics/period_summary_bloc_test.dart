import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/statistics/domain/entities/period_summary.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_state.dart';

class MockStatisticsRepository extends Mock implements StatisticsRepository {}

void main() {
  late MockStatisticsRepository mockRepository;

  setUp(() {
    mockRepository = MockStatisticsRepository();
  });

  const testSummary = PeriodSummary(
    dateFrom: '2026-04-01',
    dateTo: '2026-04-07',
    totalIncome: 500000,
    totalExpense: 320000,
    balance: 180000,
    byCategory: [
      PeriodCategoryItem(
        categoryName: '식비',
        amount: 150000,
        count: 12,
        percentage: 46.9,
      ),
    ],
    byBudget: [
      PeriodBudgetItem(
        budgetName: '식비 예산',
        budgetAmount: 300000,
        spent: 150000,
        remaining: 150000,
      ),
    ],
    byPaymentMethod: [
      PeriodPaymentMethodItem(
        methodName: '신한카드',
        amount: 200000,
        count: 15,
      ),
    ],
    byDate: [
      PeriodDateItem(
        date: '2026-04-01',
        income: 0,
        expense: 45000,
      ),
    ],
  );

  group('PeriodSummaryBloc', () {
    blocTest<PeriodSummaryBloc, PeriodSummaryState>(
      'emits [Loading, Loaded] when LoadPeriodSummary succeeds',
      build: () {
        when(() => mockRepository.getPeriodSummary(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
            )).thenAnswer((_) async => const Right(testSummary));
        return PeriodSummaryBloc(statisticsRepository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadPeriodSummary(
        dateFrom: '2026-04-01',
        dateTo: '2026-04-07',
      )),
      expect: () => [
        const PeriodSummaryLoading(),
        const PeriodSummaryLoaded(testSummary),
      ],
    );

    blocTest<PeriodSummaryBloc, PeriodSummaryState>(
      'emits [Loading, Error] when LoadPeriodSummary fails',
      build: () {
        when(() => mockRepository.getPeriodSummary(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
            )).thenAnswer(
          (_) async =>
              const Left(ServerFailure('기간별 통계를 불러오지 못했습니다')),
        );
        return PeriodSummaryBloc(statisticsRepository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadPeriodSummary(
        dateFrom: '2026-04-01',
        dateTo: '2026-04-07',
      )),
      expect: () => [
        const PeriodSummaryLoading(),
        const PeriodSummaryError('기간별 통계를 불러오지 못했습니다'),
      ],
    );

    blocTest<PeriodSummaryBloc, PeriodSummaryState>(
      'initial state is PeriodSummaryInitial',
      build: () =>
          PeriodSummaryBloc(statisticsRepository: mockRepository),
      verify: (bloc) => expect(bloc.state, const PeriodSummaryInitial()),
    );

    blocTest<PeriodSummaryBloc, PeriodSummaryState>(
      'emits [Loading, Error] when exception is thrown',
      build: () {
        when(() => mockRepository.getPeriodSummary(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
            )).thenThrow(Exception('unexpected'));
        return PeriodSummaryBloc(statisticsRepository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadPeriodSummary(
        dateFrom: '2026-04-01',
        dateTo: '2026-04-07',
      )),
      expect: () => [
        const PeriodSummaryLoading(),
        const PeriodSummaryError('기간별 통계를 불러오지 못했습니다'),
      ],
    );
  });
}
