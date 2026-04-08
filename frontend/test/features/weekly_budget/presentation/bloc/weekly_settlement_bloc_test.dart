import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_settlement_bloc.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_settlement_event.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_settlement_state.dart';
import 'package:budget_book/features/weekly_budget/domain/repositories/weekly_settlement_repository.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_settlement.dart';
import 'package:budget_book/core/error/failure.dart';

class MockWeeklySettlementRepository extends Mock
    implements WeeklySettlementRepository {
  @override
  Future<Either<Failure, WeeklySettlementOverview>> getSettlements(
          int year, int month) =>
      super.noSuchMethod(
        Invocation.method(#getSettlements, [year, month]),
        returnValue: Future.value(
          const Right<Failure, WeeklySettlementOverview>(
            WeeklySettlementOverview(yearMonth: '', weeks: []),
          ),
        ),
      ) as Future<Either<Failure, WeeklySettlementOverview>>;

  @override
  Future<Either<Failure, void>> settle(
          List<String> budgetIds, int weekNumber) =>
      super.noSuchMethod(
        Invocation.method(#settle, [budgetIds, weekNumber]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, void>> unsettle(
          List<String> budgetIds, int weekNumber) =>
      super.noSuchMethod(
        Invocation.method(#unsettle, [budgetIds, weekNumber]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;
}

void main() {
  late WeeklySettlementBloc bloc;
  late MockWeeklySettlementRepository mockRepository;

  const tItem1 = WeeklySettlementItem(
    budgetId: 'b1',
    categoryName: '식비',
    categoryIcon: 'restaurant',
    categoryColor: '#FF5733',
    spentAmount: 50000,
    status: SettlementStatus.pending,
  );

  const tItem2 = WeeklySettlementItem(
    budgetId: 'b2',
    categoryName: '교통비',
    categoryIcon: 'directions_bus',
    categoryColor: '#2196F3',
    spentAmount: 30000,
    status: SettlementStatus.settled,
    settledAt: '2026-04-06',
  );

  const tWeek1 = WeeklySettlementWeek(
    weekNumber: 1,
    weekStart: '2026-04-01',
    weekEnd: '2026-04-05',
    totalSpent: 80000,
    settledCount: 1,
    totalCount: 2,
    items: [tItem1, tItem2],
  );

  const tOverview = WeeklySettlementOverview(
    yearMonth: '2026-04',
    weeks: [tWeek1],
  );

  const tSettledOverview = WeeklySettlementOverview(
    yearMonth: '2026-04',
    weeks: [
      WeeklySettlementWeek(
        weekNumber: 1,
        weekStart: '2026-04-01',
        weekEnd: '2026-04-05',
        totalSpent: 80000,
        settledCount: 2,
        totalCount: 2,
        items: [
          WeeklySettlementItem(
            budgetId: 'b1',
            categoryName: '식비',
            spentAmount: 50000,
            status: SettlementStatus.settled,
            settledAt: '2026-04-07',
          ),
          tItem2,
        ],
      ),
    ],
  );

  setUp(() {
    mockRepository = MockWeeklySettlementRepository();
    bloc = WeeklySettlementBloc(settlementRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('WeeklySettlementBloc', () {
    test('initial state is SettlementInitial', () {
      expect(bloc.state, const SettlementInitial());
    });

    group('LoadSettlements', () {
      blocTest<WeeklySettlementBloc, WeeklySettlementState>(
        'emits [Loading, Loaded] on success',
        build: () {
          when(mockRepository.getSettlements(2026, 4))
              .thenAnswer((_) async => const Right(tOverview));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const LoadSettlements(year: 2026, month: 4)),
        expect: () => [
          const SettlementLoading(),
          const SettlementLoaded(overview: tOverview),
        ],
      );

      blocTest<WeeklySettlementBloc, WeeklySettlementState>(
        'emits [Loading, Error] on failure',
        build: () {
          when(mockRepository.getSettlements(2026, 4)).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('정산 정보를 불러오지 못했습니다')));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const LoadSettlements(year: 2026, month: 4)),
        expect: () => [
          const SettlementLoading(),
          const SettlementError('정산 정보를 불러오지 못했습니다'),
        ],
      );
    });

    group('SettleItems', () {
      blocTest<WeeklySettlementBloc, WeeklySettlementState>(
        'settles items and reloads',
        build: () {
          when(mockRepository.settle(['b1'], 1))
              .thenAnswer((_) async => const Right(null));
          when(mockRepository.getSettlements(2026, 4))
              .thenAnswer((_) async => const Right(tSettledOverview));
          return bloc;
        },
        act: (bloc) => bloc.add(const SettleItems(
          budgetIds: ['b1'],
          weekNumber: 1,
          year: 2026,
          month: 4,
        )),
        expect: () => [
          const SettlementLoaded(overview: tSettledOverview),
        ],
      );

      blocTest<WeeklySettlementBloc, WeeklySettlementState>(
        'emits Error when settle fails',
        build: () {
          when(mockRepository.settle(['b1'], 1)).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('정산 처리에 실패했습니다')));
          return bloc;
        },
        act: (bloc) => bloc.add(const SettleItems(
          budgetIds: ['b1'],
          weekNumber: 1,
          year: 2026,
          month: 4,
        )),
        expect: () => [
          const SettlementError('정산 처리에 실패했습니다'),
        ],
      );
    });

    group('UnsettleItems', () {
      blocTest<WeeklySettlementBloc, WeeklySettlementState>(
        'unsettles items and reloads',
        build: () {
          when(mockRepository.unsettle(['b2'], 1))
              .thenAnswer((_) async => const Right(null));
          when(mockRepository.getSettlements(2026, 4))
              .thenAnswer((_) async => const Right(tOverview));
          return bloc;
        },
        act: (bloc) => bloc.add(const UnsettleItems(
          budgetIds: ['b2'],
          weekNumber: 1,
          year: 2026,
          month: 4,
        )),
        expect: () => [
          const SettlementLoaded(overview: tOverview),
        ],
      );

      blocTest<WeeklySettlementBloc, WeeklySettlementState>(
        'emits Error when unsettle fails',
        build: () {
          when(mockRepository.unsettle(['b2'], 1)).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('정산 취소에 실패했습니다')));
          return bloc;
        },
        act: (bloc) => bloc.add(const UnsettleItems(
          budgetIds: ['b2'],
          weekNumber: 1,
          year: 2026,
          month: 4,
        )),
        expect: () => [
          const SettlementError('정산 취소에 실패했습니다'),
        ],
      );
    });
  });

  group('WeeklySettlementItem entity', () {
    test('displayName returns categoryName', () {
      expect(tItem1.displayName, '식비');
    });

    test('displayName returns groupName when categoryName is null', () {
      const item = WeeklySettlementItem(
        budgetId: 'b3',
        groupName: '생활비',
        spentAmount: 10000,
        status: SettlementStatus.pending,
      );
      expect(item.displayName, '생활비');
    });

    test('isSettled returns true for settled status', () {
      expect(tItem2.isSettled, true);
    });

    test('isSettled returns false for pending status', () {
      expect(tItem1.isSettled, false);
    });
  });

  group('WeeklySettlementWeek entity', () {
    test('isFullySettled returns false when not all settled', () {
      expect(tWeek1.isFullySettled, false);
    });

    test('isFullySettled returns true when all settled', () {
      const fullySettledWeek = WeeklySettlementWeek(
        weekNumber: 1,
        weekStart: '2026-04-01',
        weekEnd: '2026-04-05',
        totalSpent: 80000,
        settledCount: 2,
        totalCount: 2,
        items: [tItem2, tItem2],
      );
      expect(fullySettledWeek.isFullySettled, true);
    });

    test('isFullySettled returns false when totalCount is 0', () {
      const emptyWeek = WeeklySettlementWeek(
        weekNumber: 1,
        weekStart: '2026-04-01',
        weekEnd: '2026-04-05',
        totalSpent: 0,
        settledCount: 0,
        totalCount: 0,
        items: [],
      );
      expect(emptyWeek.isFullySettled, false);
    });
  });
}
