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
              groups: [],
            ),
          ),
        ),
      ) as Future<Either<Failure, CurrentWeekSummary>>;
}

void main() {
  late WeeklyBudgetBloc bloc;
  late MockWeeklyBudgetRepository mockRepository;

  const tWeek1 = WeekSummary(
    weekNumber: 1,
    weekStart: '2026-03-01',
    weekEnd: '2026-03-07',
    budgetAmount: 200000,
    spentAmount: 180000,
    remainingAmount: 20000,
    usageRate: 90.0,
    status: 'UNDER',
  );

  const tWeek2 = WeekSummary(
    weekNumber: 2,
    weekStart: '2026-03-08',
    weekEnd: '2026-03-14',
    budgetAmount: 200000,
    spentAmount: 240000,
    remainingAmount: -40000,
    usageRate: 120.0,
    status: 'OVER',
  );

  const tOverview = WeeklyOverview(
    yearMonth: '2026-03',
    weeks: [tWeek1, tWeek2],
  );

  const tGroupSummary = WeeklyGroupSummary(
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
    groups: [tGroupSummary],
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
          const WeeklyBudgetLoaded(overview: tOverview),
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
        seed: () => const WeeklyBudgetLoaded(currentWeek: tCurrentWeek),
        act: (bloc) =>
            bloc.add(const LoadWeeklyOverview(year: 2026, month: 3)),
        expect: () => [
          const WeeklyBudgetLoading(),
          const WeeklyBudgetLoaded(
              overview: tOverview, currentWeek: tCurrentWeek),
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
          const WeeklyBudgetLoaded(currentWeek: tCurrentWeek),
        ],
      );

      blocTest<WeeklyBudgetBloc, WeeklyBudgetState>(
        'preserves overview when loading current week',
        build: () {
          when(mockRepository.getCurrentWeekSummary())
              .thenAnswer((_) async => const Right(tCurrentWeek));
          return bloc;
        },
        seed: () => const WeeklyBudgetLoaded(overview: tOverview),
        act: (bloc) => bloc.add(const LoadCurrentWeek()),
        expect: () => [
          const WeeklyBudgetLoaded(
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
        seed: () => const WeeklyBudgetLoaded(overview: tOverview),
        act: (bloc) => bloc.add(const LoadCurrentWeek()),
        expect: () => <WeeklyBudgetState>[],
      );
    });
  });

  group('WeekSummary entity', () {
    test('isOver returns true for OVER status', () {
      expect(tWeek2.isOver, true);
      expect(tWeek2.isUnder, false);
      expect(tWeek2.isInProgress, false);
    });

    test('isUnder returns true for UNDER status', () {
      expect(tWeek1.isUnder, true);
      expect(tWeek1.isOver, false);
    });
  });
}
