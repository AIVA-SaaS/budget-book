import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/features/pocket/domain/repositories/pocket_repository.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/domain/entities/distribute_result.dart';
import 'package:budget_book/core/error/failure.dart';

class MockPocketRepository extends Mock implements PocketRepository {
  @override
  Future<Either<Failure, List<MoneyPocket>>> getPockets() =>
      super.noSuchMethod(
        Invocation.method(#getPockets, []),
        returnValue: Future.value(
          const Right<Failure, List<MoneyPocket>>([]),
        ),
      ) as Future<Either<Failure, List<MoneyPocket>>>;

  @override
  Future<Either<Failure, MoneyPocket>> createPocket({
    required String name,
    required String type,
    required int allocatedAmount,
    String? icon,
    String? color,
    int? goalAmount,
    String? targetDate,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createPocket, [], {
          #name: name,
          #type: type,
          #allocatedAmount: allocatedAmount,
          #icon: icon,
          #color: color,
          #goalAmount: goalAmount,
          #targetDate: targetDate,
        }),
        returnValue: Future.value(
          const Right<Failure, MoneyPocket>(MoneyPocket(
            id: '',
            name: '',
            type: 'LIVING',
            allocatedAmount: 0,
            balance: 0,
            displayOrder: 0,
            isActive: true,
          )),
        ),
      ) as Future<Either<Failure, MoneyPocket>>;

  @override
  Future<Either<Failure, MoneyPocket>> updatePocket({
    required String id,
    String? name,
    String? type,
    int? allocatedAmount,
    String? icon,
    String? color,
    int? displayOrder,
    int? goalAmount,
    String? targetDate,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updatePocket, [], {
          #id: id,
          #name: name,
          #type: type,
          #allocatedAmount: allocatedAmount,
          #icon: icon,
          #color: color,
          #displayOrder: displayOrder,
          #goalAmount: goalAmount,
          #targetDate: targetDate,
        }),
        returnValue: Future.value(
          const Right<Failure, MoneyPocket>(MoneyPocket(
            id: '',
            name: '',
            type: 'LIVING',
            allocatedAmount: 0,
            balance: 0,
            displayOrder: 0,
            isActive: true,
          )),
        ),
      ) as Future<Either<Failure, MoneyPocket>>;

  @override
  Future<Either<Failure, void>> deletePocket(String id) =>
      super.noSuchMethod(
        Invocation.method(#deletePocket, [id]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, DistributeResult>> distributeIncome({
    required int totalAmount,
    required List<Map<String, dynamic>> distributions,
  }) =>
      super.noSuchMethod(
        Invocation.method(#distributeIncome, [], {
          #totalAmount: totalAmount,
          #distributions: distributions,
        }),
        returnValue: Future.value(
          const Right<Failure, DistributeResult>(DistributeResult(
            distributions: [],
            totalDistributed: 0,
          )),
        ),
      ) as Future<Either<Failure, DistributeResult>>;

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>>
      getDistributionRatios() =>
          super.noSuchMethod(
            Invocation.method(#getDistributionRatios, []),
            returnValue: Future.value(
              const Right<Failure, List<Map<String, dynamic>>>([]),
            ),
          ) as Future<Either<Failure, List<Map<String, dynamic>>>>;

  @override
  Future<Either<Failure, void>> saveDistributionRatios(
          List<Map<String, dynamic>> ratios) =>
      super.noSuchMethod(
        Invocation.method(#saveDistributionRatios, [ratios]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;
}

void main() {
  late PocketBloc bloc;
  late MockPocketRepository mockRepository;

  const tLivingPocket = MoneyPocket(
    id: 'pocket-1',
    name: '생활비',
    type: 'LIVING',
    allocatedAmount: 1000000,
    balance: 750000,
    icon: 'home',
    color: '#4CAF50',
    displayOrder: 0,
    isActive: true,
  );

  const tSavingsPocket = MoneyPocket(
    id: 'pocket-2',
    name: '저축',
    type: 'SAVINGS',
    allocatedAmount: 500000,
    balance: 500000,
    icon: 'savings',
    color: '#2196F3',
    displayOrder: 1,
    isActive: true,
  );

  const tNewPocket = MoneyPocket(
    id: 'pocket-3',
    name: '고정지출',
    type: 'FIXED',
    allocatedAmount: 300000,
    balance: 300000,
    icon: 'payments',
    color: '#FF9800',
    displayOrder: 2,
    isActive: true,
  );

  final tPockets = [tLivingPocket, tSavingsPocket];

  setUp(() {
    mockRepository = MockPocketRepository();
    bloc = PocketBloc(pocketRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('PocketBloc', () {
    test('initial state is PocketInitial', () {
      expect(bloc.state, const PocketInitial());
    });

    group('LoadPockets', () {
      blocTest<PocketBloc, PocketState>(
        'emits [PocketLoading, PocketLoaded] on success',
        build: () {
          when(mockRepository.getPockets())
              .thenAnswer((_) async => Right(tPockets));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadPockets()),
        expect: () => [
          const PocketLoading(),
          PocketLoaded(tPockets),
        ],
      );

      blocTest<PocketBloc, PocketState>(
        'emits [PocketLoading, PocketError] on failure',
        build: () {
          when(mockRepository.getPockets()).thenAnswer(
              (_) async => const Left(ServerFailure('Failed to load pockets')));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadPockets()),
        expect: () => [
          const PocketLoading(),
          const PocketError('Failed to load pockets'),
        ],
      );
    });

    group('CreatePocket', () {
      blocTest<PocketBloc, PocketState>(
        'emits [PocketLoaded] with new pocket appended',
        build: () {
          when(mockRepository.createPocket(
            name: '고정지출',
            type: 'FIXED',
            allocatedAmount: 300000,
            icon: 'payments',
            color: '#FF9800',
          )).thenAnswer((_) async => const Right(tNewPocket));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const CreatePocket(
          name: '고정지출',
          type: 'FIXED',
          allocatedAmount: 300000,
          icon: 'payments',
          color: '#FF9800',
        )),
        expect: () => [
          PocketLoaded([...tPockets, tNewPocket]),
        ],
      );

      blocTest<PocketBloc, PocketState>(
        'emits [PocketLoaded with operationError] on failure',
        build: () {
          when(mockRepository.createPocket(
            name: '고정지출',
            type: 'FIXED',
            allocatedAmount: 300000,
            icon: 'payments',
            color: '#FF9800',
          )).thenAnswer(
              (_) async => const Left(ServerFailure('Failed to create pocket')));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const CreatePocket(
          name: '고정지출',
          type: 'FIXED',
          allocatedAmount: 300000,
          icon: 'payments',
          color: '#FF9800',
        )),
        expect: () => [
          PocketLoaded(tPockets,
              operationError: 'Failed to create pocket'),
        ],
      );

      blocTest<PocketBloc, PocketState>(
        'emits [PocketLoaded] with goal fields when creating with goal',
        build: () {
          const pocketWithGoal = MoneyPocket(
            id: 'pocket-g1',
            name: '여행',
            type: 'SAVINGS',
            allocatedAmount: 0,
            balance: 0,
            icon: 'savings',
            color: '#2196F3',
            displayOrder: 3,
            isActive: true,
            goalAmount: 3000000,
            targetDate: '2026-12-31',
          );
          when(mockRepository.createPocket(
            name: '여행',
            type: 'SAVINGS',
            allocatedAmount: 0,
            icon: 'savings',
            color: '#2196F3',
            goalAmount: 3000000,
            targetDate: '2026-12-31',
          )).thenAnswer((_) async => const Right(pocketWithGoal));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const CreatePocket(
          name: '여행',
          type: 'SAVINGS',
          allocatedAmount: 0,
          icon: 'savings',
          color: '#2196F3',
          goalAmount: 3000000,
          targetDate: '2026-12-31',
        )),
        expect: () => [
          isA<PocketLoaded>().having(
            (s) => s.pockets.last.goalAmount,
            'last pocket goalAmount',
            3000000,
          ),
        ],
      );
    });

    group('UpdatePocket', () {
      const tUpdatedPocket = MoneyPocket(
        id: 'pocket-1',
        name: '생활비 (변경)',
        type: 'LIVING',
        allocatedAmount: 1200000,
        balance: 950000,
        icon: 'home',
        color: '#4CAF50',
        displayOrder: 0,
        isActive: true,
      );

      blocTest<PocketBloc, PocketState>(
        'emits [PocketLoaded] with updated pocket in list',
        build: () {
          when(mockRepository.updatePocket(
            id: 'pocket-1',
            name: '생활비 (변경)',
            allocatedAmount: 1200000,
          )).thenAnswer((_) async => const Right(tUpdatedPocket));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const UpdatePocket(
          id: 'pocket-1',
          name: '생활비 (변경)',
          allocatedAmount: 1200000,
        )),
        expect: () => [
          const PocketLoaded([tUpdatedPocket, tSavingsPocket]),
        ],
      );

      blocTest<PocketBloc, PocketState>(
        'emits [PocketLoaded with operationError] on failure',
        build: () {
          when(mockRepository.updatePocket(
            id: 'pocket-1',
            name: '생활비 (변경)',
          )).thenAnswer(
              (_) async => const Left(ServerFailure('Failed to update pocket')));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const UpdatePocket(
          id: 'pocket-1',
          name: '생활비 (변경)',
        )),
        expect: () => [
          PocketLoaded(tPockets,
              operationError: 'Failed to update pocket'),
        ],
      );
    });

    group('DeletePocket', () {
      blocTest<PocketBloc, PocketState>(
        'emits [PocketLoaded] with pocket removed',
        build: () {
          when(mockRepository.deletePocket('pocket-2'))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const DeletePocket('pocket-2')),
        expect: () => [
          const PocketLoaded([tLivingPocket]),
        ],
      );

      blocTest<PocketBloc, PocketState>(
        'emits [PocketLoaded with operationError] on failure',
        build: () {
          when(mockRepository.deletePocket('pocket-1')).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('Failed to delete pocket')));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const DeletePocket('pocket-1')),
        expect: () => [
          PocketLoaded(tPockets,
              operationError: 'Failed to delete pocket'),
        ],
      );
    });

    group('DistributeIncome', () {
      const tDistributeResult = DistributeResult(
        distributions: [
          DistributionEntry(
              pocketId: 'pocket-1', pocketName: '생활비', amount: 600000),
          DistributionEntry(
              pocketId: 'pocket-2', pocketName: '저축', amount: 400000),
        ],
        totalDistributed: 1000000,
      );

      blocTest<PocketBloc, PocketState>(
        'emits LoadPockets after successful distribution (reloads)',
        build: () {
          when(mockRepository.distributeIncome(
            totalAmount: 1000000,
            distributions: [
              {'pocketId': 'pocket-1', 'amount': 600000},
              {'pocketId': 'pocket-2', 'amount': 400000},
            ],
          )).thenAnswer((_) async => const Right(tDistributeResult));
          when(mockRepository.getPockets())
              .thenAnswer((_) async => Right(tPockets));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const DistributeIncome(
          totalAmount: 1000000,
          distributions: [
            {'pocketId': 'pocket-1', 'amount': 600000},
            {'pocketId': 'pocket-2', 'amount': 400000},
          ],
        )),
        // 회차 12 follow-up — 이미 Loaded 면 reload 시 Loading 안 emit.
        // mock 동일 list 반환 → distinct 로 emit skip. verify 로 호출 확인.
        expect: () => [],
        verify: (_) {
          verify(mockRepository.getPockets()).called(1);
        },
      );

      blocTest<PocketBloc, PocketState>(
        'emits [PocketLoaded with operationError] on distribution failure',
        build: () {
          when(mockRepository.distributeIncome(
            totalAmount: 1000000,
            distributions: [
              {'pocketId': 'pocket-1', 'amount': 600000},
            ],
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to distribute income')));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const DistributeIncome(
          totalAmount: 1000000,
          distributions: [
            {'pocketId': 'pocket-1', 'amount': 600000},
          ],
        )),
        expect: () => [
          PocketLoaded(tPockets,
              operationError: 'Failed to distribute income'),
        ],
      );
    });

    group('LoadDistributionRatios', () {
      blocTest<PocketBloc, PocketState>(
        'emits PocketLoaded with distribution ratios on success',
        build: () {
          final ratios = [
            {'pocketId': 'pocket-1', 'percentage': 60},
            {'pocketId': 'pocket-2', 'percentage': 40},
          ];
          when(mockRepository.getDistributionRatios())
              .thenAnswer((_) async => Right(ratios));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const LoadDistributionRatios()),
        expect: () => [
          isA<PocketLoaded>().having(
            (s) => s.distributionRatios,
            'distributionRatios',
            [
              {'pocketId': 'pocket-1', 'percentage': 60},
              {'pocketId': 'pocket-2', 'percentage': 40},
            ],
          ),
        ],
      );

      blocTest<PocketBloc, PocketState>(
        'emits PocketLoaded with operationError on failure',
        build: () {
          when(mockRepository.getDistributionRatios()).thenAnswer((_) async =>
              const Left(
                  ServerFailure('Failed to load distribution ratios')));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const LoadDistributionRatios()),
        expect: () => [
          PocketLoaded(tPockets,
              operationError: 'Failed to load distribution ratios'),
        ],
      );
    });

    group('SaveDistributionRatios', () {
      blocTest<PocketBloc, PocketState>(
        'emits PocketLoaded with ratiosSaved=true on success',
        build: () {
          final ratios = [
            {'pocketId': 'pocket-1', 'percentage': 60},
            {'pocketId': 'pocket-2', 'percentage': 40},
          ];
          when(mockRepository.saveDistributionRatios(ratios))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () => PocketLoaded(tPockets),
        act: (bloc) => bloc.add(const SaveDistributionRatios(ratios: [
          {'pocketId': 'pocket-1', 'percentage': 60},
          {'pocketId': 'pocket-2', 'percentage': 40},
        ])),
        expect: () => [
          isA<PocketLoaded>().having(
            (s) => s.ratiosSaved,
            'ratiosSaved',
            true,
          ),
        ],
      );
    });
  });

  group('PocketLoaded helpers', () {
    test('totalBalance sums all pocket balances', () {
      final state = PocketLoaded(tPockets);
      expect(state.totalBalance, 1250000);
    });

    test('totalAllocated sums all allocated amounts', () {
      final state = PocketLoaded(tPockets);
      expect(state.totalAllocated, 1500000);
    });

    test('activePockets returns only active pockets', () {
      const inactivePocket = MoneyPocket(
        id: 'pocket-4',
        name: '비활성',
        type: 'CUSTOM',
        allocatedAmount: 0,
        balance: 0,
        displayOrder: 4,
        isActive: false,
      );
      final state = PocketLoaded([...tPockets, inactivePocket]);
      expect(state.activePockets, tPockets);
    });
  });

  group('MoneyPocket entity', () {
    test('isLiving returns true for LIVING type', () {
      expect(tLivingPocket.isLiving, true);
      expect(tLivingPocket.isSavings, false);
    });

    test('isSavings returns true for SAVINGS type', () {
      expect(tSavingsPocket.isSavings, true);
      expect(tSavingsPocket.isLiving, false);
    });

    test('isFixed returns true for FIXED type', () {
      expect(tNewPocket.isFixed, true);
    });

    test('goalProgress returns null when no goal set', () {
      expect(tLivingPocket.goalProgress, null);
    });

    test('goalProgress returns correct ratio', () {
      const pocketWithGoal = MoneyPocket(
        id: 'g1',
        name: 'Goal',
        type: 'SAVINGS',
        allocatedAmount: 0,
        balance: 750000,
        displayOrder: 0,
        isActive: true,
        goalAmount: 1000000,
      );
      expect(pocketWithGoal.goalProgress, 0.75);
    });

    test('goalProgress handles zero goalAmount', () {
      const pocket = MoneyPocket(
        id: 'g2',
        name: 'Zero',
        type: 'SAVINGS',
        allocatedAmount: 0,
        balance: 100,
        displayOrder: 0,
        isActive: true,
        goalAmount: 0,
      );
      expect(pocket.goalProgress, null);
    });
  });
}
