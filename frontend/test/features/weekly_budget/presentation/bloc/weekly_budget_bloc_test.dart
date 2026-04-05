import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_bloc.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_event.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_state.dart';
import 'package:budget_book/features/weekly_budget/domain/repositories/weekly_budget_repository.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_overview.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/current_week_summary.dart';
import 'package:budget_book/core/error/failure.dart';

class MockWeeklyBudgetRepository extends Mock
    implements WeeklyBudgetRepository {
  @override
  Future<Either<Failure, WeeklyOverview>> getWeeklyOverview(
          int year, int month) =>
      super.noSuchMethod(
        Invocation.method(#getWeeklyOverview, [year, month]),
        returnValue: Future.value(
          const Right<Failure, WeeklyOverview>(
            WeeklyOverview(yearMonth: '', weeks: []),
          ),
        ),
      ) as Future<Either<Failure, WeeklyOverview>>;

  @override
  Future<Either<Failure, CurrentWeekSummary>> getCurrentWeekSummary() =>
      super.noSuchMethod(
        Invocation.method(#getCurrentWeekSummary, []),
        returnValue: Future.value(
          const Right<Failure, CurrentWeekSummary>(
            CurrentWeekSummary(
              yearMonth: '',
              weekNumber: 1,
              weekStart: '',
              weekEnd: '',
              items: [],
            ),
          ),
        ),
      ) as Future<Either<Failure, CurrentWeekSummary>>;
}

void main() {
  late WeeklyBudgetBloc bloc;
  late MockWeeklyBudgetRepository mockRepository;

  const tItem1 = WeeklyBudgetItem(
    budgetId: 'b1',
    groupId: 'g1',
    groupName: '생활비',
    budgetAmount: 200000,
    spentAmount: 80000,
    remainingAmount: 120000,
    usageRate: 40.0,
  );

  const tItem2 = WeeklyBudgetItem(
    budgetId: 'b2',
    groupId: 'g2',
    groupName: '투자',
    budgetAmount: 200000,
    spentAmount: 40000,
    remainingAmount: 160000,
    usageRate: 20.0,
  );

  const tWeek1 = WeeklyWeek(
    weekNumber: 1,
    weekStart: '2026-03-01',
    weekEnd: '2026-03-07',
    totalBudget: 400000,
    totalSpent: 120000,
    totalRemaining: 280000,
    items: [tItem1, tItem2],
  );

  const tWeek2 = WeeklyWeek(
    weekNumber: 2,
    weekStart: '2026-03-08',
    weekEnd: '2026-03-14',
    totalBudget: 400000,
    totalSpent: 500000,
    totalRemaining: -100000,
    items: [tItem1],
  );

  const tOverview = WeeklyOverview(
    yearMonth: '2026-03',
    weeks: [tWeek1, tWeek2],
  );

  const tCurrentWeekItem = WeeklyBudgetItem(
    budgetId: 'b1',
    groupId: 'g1',
    groupName: '생활비',
    budgetAmount: 200000,
    spentAmount: 120000,
    remainingAmount: 80000,
    usageRate: 60.0,
  );

  const tCurrentWeek = CurrentWeekSummary(
    yearMonth: '2026-03',
    weekNumber: 2,
    weekStart: '2026-03-08',
    weekEnd: '2026-03-14',
    items: [tCurrentWeekItem],
  );

  setUp(() {
    mockRepository = MockWeeklyBudgetRepository();
    bloc = WeeklyBudgetBloc(weeklyBudgetRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('WeeklyBudgetBloc', () {
    test('initial state is WeeklyBudgetInitial', () {
      expect(bloc.state, const WeeklyBudgetInitial());
    });

    group('LoadWeeklyOverview', () {
      blocTest<WeeklyBudgetBloc, WeeklyBudgetState>(
        'emits [Loading, Loaded] on success',
        build: () {
          when(mockRepository.getWeeklyOverview(2026, 3))
              .thenAnswer((_) async => const Right(tOverview));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const LoadWeeklyOverview(year: 2026, month: 3)),
        expect: () => [
          const WeeklyBudgetLoading(),
          WeeklyBudgetLoaded(overview: tOverview, year: 2026, month: 3),
        ],
      );

      blocTest<WeeklyBudgetBloc, WeeklyBudgetState>(
        'emits [Loading, Error] on failure',
        build: () {
          when(mockRepository.getWeeklyOverview(2026, 3)).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('주간 예산 정보를 불러오지 못했습니다')));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const LoadWeeklyOverview(year: 2026, month: 3)),
        expect: () => [
          const WeeklyBudgetLoading(),
          const WeeklyBudgetError('주간 예산 정보를 불러오지 못했습니다'),
        ],
      );

      blocTest<WeeklyBudgetBloc, WeeklyBudgetState>(
        'preserves currentWeek when loading overview',
        build: () {
          when(mockRepository.getWeeklyOverview(2026, 3))
              .thenAnswer((_) async => const Right(tOverview));
          return bloc;
        },
        seed: () => WeeklyBudgetLoaded(currentWeek: tCurrentWeek),
        act: (bloc) =>
            bloc.add(const LoadWeeklyOverview(year: 2026, month: 3)),
        expect: () => [
          const WeeklyBudgetLoading(),
          WeeklyBudgetLoaded(
              overview: tOverview, currentWeek: tCurrentWeek, year: 2026, month: 3),
        ],
      );
    });

    group('LoadCurrentWeek', () {
      blocTest<WeeklyBudgetBloc, WeeklyBudgetState>(
        'emits [Loading, Loaded] on success from initial state',
        build: () {
          when(mockRepository.getCurrentWeekSummary())
              .thenAnswer((_) async => const Right(tCurrentWeek));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadCurrentWeek()),
        expect: () => [
          const WeeklyBudgetLoading(),
          WeeklyBudgetLoaded(currentWeek: tCurrentWeek),
        ],
      );

      blocTest<WeeklyBudgetBloc, WeeklyBudgetState>(
        'preserves overview when loading current week',
        build: () {
          when(mockRepository.getCurrentWeekSummary())
              .thenAnswer((_) async => const Right(tCurrentWeek));
          return bloc;
        },
        seed: () => WeeklyBudgetLoaded(overview: tOverview),
        act: (bloc) => bloc.add(const LoadCurrentWeek()),
        expect: () => [
          WeeklyBudgetLoaded(
              overview: tOverview, currentWeek: tCurrentWeek),
        ],
      );

      blocTest<WeeklyBudgetBloc, WeeklyBudgetState>(
        'emits nothing on current week failure when overview already exists (state unchanged)',
        build: () {
          when(mockRepository.getCurrentWeekSummary()).thenAnswer((_) async =>
              const Left(
                  ServerFailure('이번 주 예산 정보를 불러오지 못했습니다')));
          return bloc;
        },
        seed: () => WeeklyBudgetLoaded(overview: tOverview),
        act: (bloc) => bloc.add(const LoadCurrentWeek()),
        expect: () => <WeeklyBudgetState>[],
      );
    });
  });

  group('WeeklyWeek entity', () {
    test('totalUsageRate computes correctly', () {
      expect(tWeek1.totalUsageRate, 30.0);
    });

    test('totalUsageRate is 0 when totalBudget is 0', () {
      const emptyWeek = WeeklyWeek(
        weekNumber: 1,
        weekStart: '2026-03-01',
        weekEnd: '2026-03-07',
        totalBudget: 0,
        totalSpent: 0,
        totalRemaining: 0,
        items: [],
      );
      expect(emptyWeek.totalUsageRate, 0.0);
    });
  });

  group('WeeklyBudgetItem entity', () {
    test('displayName returns groupName when categoryName is null', () {
      expect(tItem1.displayName, '생활비');
    });

    test('displayName returns categoryName when available', () {
      const itemWithCategory = WeeklyBudgetItem(
        budgetId: 'b3',
        categoryId: 'c1',
        categoryName: '식비',
        groupId: 'g1',
        groupName: '생활비',
        budgetAmount: 100000,
        spentAmount: 50000,
        remainingAmount: 50000,
        usageRate: 50.0,
      );
      expect(itemWithCategory.displayName, '식비');
    });
  });

  group('CurrentWeekSummary entity', () {
    test('totalBudget sums item budgetAmounts', () {
      expect(tCurrentWeek.totalBudget, 200000);
    });

    test('totalSpent sums item spentAmounts', () {
      expect(tCurrentWeek.totalSpent, 120000);
    });

    test('totalRemaining sums item remainingAmounts', () {
      expect(tCurrentWeek.totalRemaining, 80000);
    });
  });
}
