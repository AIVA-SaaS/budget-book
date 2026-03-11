import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/report/presentation/bloc/report_bloc.dart';
import 'package:budget_book/features/report/presentation/bloc/report_event.dart';
import 'package:budget_book/features/report/presentation/bloc/report_state.dart';
import 'package:budget_book/features/report/domain/repositories/report_repository.dart';
import 'package:budget_book/features/report/domain/entities/weekly_report.dart';
import 'package:budget_book/features/report/domain/entities/monthly_report.dart';
import 'package:budget_book/core/error/failure.dart';

class MockReportRepository extends Mock implements ReportRepository {
  @override
  Future<Either<Failure, WeeklyReport>> getWeeklyReport(
          int year, int month, int week) =>
      super.noSuchMethod(
        Invocation.method(#getWeeklyReport, [year, month, week]),
        returnValue: Future.value(
          const Right<Failure, WeeklyReport>(
            WeeklyReport(
              yearMonth: '',
              weekNumber: 1,
              weekStart: '',
              weekEnd: '',
              totalBudget: 0,
              totalSpent: 0,
              remainingAmount: 0,
              usageRate: 0,
              status: 'UNDER',
              topOverspendCategories: [],
              dailySpending: [],
              peakSpendingDay: 'MON',
            ),
          ),
        ),
      ) as Future<Either<Failure, WeeklyReport>>;

  @override
  Future<Either<Failure, MonthlyReport>> getMonthlyReport(
          int year, int month) =>
      super.noSuchMethod(
        Invocation.method(#getMonthlyReport, [year, month]),
        returnValue: Future.value(
          const Right<Failure, MonthlyReport>(
            MonthlyReport(
              yearMonth: '',
              totalIncome: 0,
              totalExpense: 0,
              balance: 0,
              groupSummaries: [],
              topCategories: [],
              dayOfWeekPattern: [],
            ),
          ),
        ),
      ) as Future<Either<Failure, MonthlyReport>>;
}

void main() {
  late ReportBloc bloc;
  late MockReportRepository mockRepository;

  const tDailySpending = DailySpending(
    date: '2026-03-08',
    dayOfWeek: 'SUN',
    amount: 45000,
    transactionCount: 3,
  );

  const tOverspendCategory = OverspendCategory(
    categoryId: 'c1',
    categoryName: '외식',
    categoryType: 'EXPENSE',
    categoryIcon: 'restaurant',
    categoryColor: '#FF5733',
    amount: 82000,
    averageAmount: 50000,
    deviation: 32000,
    transactionCount: 3,
  );

  const tWeeklyReport = WeeklyReport(
    yearMonth: '2026-03',
    weekNumber: 2,
    weekStart: '2026-03-08',
    weekEnd: '2026-03-14',
    totalBudget: 200000,
    totalSpent: 240000,
    remainingAmount: -40000,
    usageRate: 120.0,
    status: 'OVER',
    topOverspendCategories: [tOverspendCategory],
    dailySpending: [tDailySpending],
    peakSpendingDay: 'FRI',
  );

  const tMonthComparison = MonthComparison(
    previousYearMonth: '2026-02',
    incomeChange: 100000,
    expenseChange: -50000,
    incomeChangeRate: 2.9,
    expenseChangeRate: -1.8,
  );

  const tMonthlyReport = MonthlyReport(
    yearMonth: '2026-03',
    totalIncome: 3500000,
    totalExpense: 2800000,
    balance: 700000,
    groupSummaries: [],
    topCategories: [],
    previousMonthComparison: tMonthComparison,
    dayOfWeekPattern: [],
  );

  setUp(() {
    mockRepository = MockReportRepository();
    bloc = ReportBloc(reportRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('ReportBloc', () {
    test('initial state is ReportInitial', () {
      expect(bloc.state, const ReportInitial());
    });

    group('LoadWeeklyReport', () {
      blocTest<ReportBloc, ReportState>(
        'emits [Loading, Loaded] on success',
        build: () {
          when(mockRepository.getWeeklyReport(2026, 3, 2))
              .thenAnswer((_) async => const Right(tWeeklyReport));
          return bloc;
        },
        act: (bloc) => bloc.add(
            const LoadWeeklyReport(year: 2026, month: 3, week: 2)),
        expect: () => [
          const ReportLoading(),
          const ReportLoaded(weeklyReport: tWeeklyReport),
        ],
      );

      blocTest<ReportBloc, ReportState>(
        'emits [Loading, Error] on failure',
        build: () {
          when(mockRepository.getWeeklyReport(2026, 3, 2)).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('주간 리포트를 불러오지 못했습니다')));
          return bloc;
        },
        act: (bloc) => bloc.add(
            const LoadWeeklyReport(year: 2026, month: 3, week: 2)),
        expect: () => [
          const ReportLoading(),
          const ReportError('주간 리포트를 불러오지 못했습니다'),
        ],
      );

      blocTest<ReportBloc, ReportState>(
        'preserves monthly report when loading weekly',
        build: () {
          when(mockRepository.getWeeklyReport(2026, 3, 2))
              .thenAnswer((_) async => const Right(tWeeklyReport));
          return bloc;
        },
        seed: () => const ReportLoaded(monthlyReport: tMonthlyReport),
        act: (bloc) => bloc.add(
            const LoadWeeklyReport(year: 2026, month: 3, week: 2)),
        expect: () => [
          const ReportLoading(),
          const ReportLoaded(
              weeklyReport: tWeeklyReport, monthlyReport: tMonthlyReport),
        ],
      );
    });

    group('LoadMonthlyReport', () {
      blocTest<ReportBloc, ReportState>(
        'emits [Loading, Loaded] on success',
        build: () {
          when(mockRepository.getMonthlyReport(2026, 3))
              .thenAnswer((_) async => const Right(tMonthlyReport));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const LoadMonthlyReport(year: 2026, month: 3)),
        expect: () => [
          const ReportLoading(),
          const ReportLoaded(monthlyReport: tMonthlyReport),
        ],
      );

      blocTest<ReportBloc, ReportState>(
        'emits [Loading, Error] on failure',
        build: () {
          when(mockRepository.getMonthlyReport(2026, 3)).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('월간 리포트를 불러오지 못했습니다')));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const LoadMonthlyReport(year: 2026, month: 3)),
        expect: () => [
          const ReportLoading(),
          const ReportError('월간 리포트를 불러오지 못했습니다'),
        ],
      );

      blocTest<ReportBloc, ReportState>(
        'preserves weekly report when loading monthly',
        build: () {
          when(mockRepository.getMonthlyReport(2026, 3))
              .thenAnswer((_) async => const Right(tMonthlyReport));
          return bloc;
        },
        seed: () => const ReportLoaded(weeklyReport: tWeeklyReport),
        act: (bloc) =>
            bloc.add(const LoadMonthlyReport(year: 2026, month: 3)),
        expect: () => [
          const ReportLoading(),
          const ReportLoaded(
              weeklyReport: tWeeklyReport, monthlyReport: tMonthlyReport),
        ],
      );
    });
  });

  group('WeeklyReport entity', () {
    test('isOver returns true for OVER status', () {
      expect(tWeeklyReport.isOver, true);
    });
  });
}
