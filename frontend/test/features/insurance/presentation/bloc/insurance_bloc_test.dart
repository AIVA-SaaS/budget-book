import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_bloc.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_event.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_state.dart';
import 'package:budget_book/features/insurance/domain/repositories/insurance_repository.dart';
import 'package:budget_book/features/insurance/domain/entities/insurance.dart';
import 'package:budget_book/core/error/failure.dart';

class MockInsuranceRepository extends Mock implements InsuranceRepository {
  @override
  Future<Either<Failure, List<Insurance>>> getInsurances({bool? active}) =>
      super.noSuchMethod(
        Invocation.method(#getInsurances, [], {#active: active}),
        returnValue:
            Future.value(const Right<Failure, List<Insurance>>([])),
      ) as Future<Either<Failure, List<Insurance>>>;

  @override
  Future<Either<Failure, Insurance>> createInsurance({
    required String name,
    String? insurer,
    required String insuranceType,
    required int premiumAmount,
    int? paymentDay,
    String? paymentCycle,
    String? paymentMethodId,
    String? categoryId,
    String? startDate,
    String? endDate,
    String? memo,
    String? visibility,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createInsurance, [], {
          #name: name,
          #insurer: insurer,
          #insuranceType: insuranceType,
          #premiumAmount: premiumAmount,
          #paymentDay: paymentDay,
          #paymentCycle: paymentCycle,
          #paymentMethodId: paymentMethodId,
          #categoryId: categoryId,
          #startDate: startDate,
          #endDate: endDate,
          #memo: memo,
          #visibility: visibility,
        }),
        returnValue: Future.value(
          Right<Failure, Insurance>(_dummyInsurance),
        ),
      ) as Future<Either<Failure, Insurance>>;

  @override
  Future<Either<Failure, Insurance>> updateInsurance({
    required String id,
    String? name,
    String? insurer,
    bool clearInsurer = false,
    String? insuranceType,
    int? premiumAmount,
    int? paymentDay,
    bool clearPaymentDay = false,
    String? paymentCycle,
    String? paymentMethodId,
    bool clearPaymentMethodId = false,
    String? categoryId,
    bool clearCategoryId = false,
    String? startDate,
    bool clearStartDate = false,
    String? endDate,
    bool clearEndDate = false,
    String? memo,
    bool clearMemo = false,
    bool? isActive,
    String? visibility,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateInsurance, [], {
          #id: id,
          #name: name,
          #insurer: insurer,
          #clearInsurer: clearInsurer,
          #insuranceType: insuranceType,
          #premiumAmount: premiumAmount,
          #paymentDay: paymentDay,
          #clearPaymentDay: clearPaymentDay,
          #paymentCycle: paymentCycle,
          #paymentMethodId: paymentMethodId,
          #clearPaymentMethodId: clearPaymentMethodId,
          #categoryId: categoryId,
          #clearCategoryId: clearCategoryId,
          #startDate: startDate,
          #clearStartDate: clearStartDate,
          #endDate: endDate,
          #clearEndDate: clearEndDate,
          #memo: memo,
          #clearMemo: clearMemo,
          #isActive: isActive,
          #visibility: visibility,
        }),
        returnValue: Future.value(
          Right<Failure, Insurance>(_dummyInsurance),
        ),
      ) as Future<Either<Failure, Insurance>>;

  @override
  Future<Either<Failure, void>> deleteInsurance(String id) =>
      super.noSuchMethod(
        Invocation.method(#deleteInsurance, [id]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, InsuranceSummary>> getInsuranceSummary({
    required int year,
    required int month,
  }) =>
      super.noSuchMethod(
        Invocation.method(
            #getInsuranceSummary, [], {#year: year, #month: month}),
        returnValue: Future.value(
          const Right<Failure, InsuranceSummary>(InsuranceSummary(
            year: 2026,
            month: 3,
            totalPremium: 0,
            activeCount: 0,
            items: [],
          )),
        ),
      ) as Future<Either<Failure, InsuranceSummary>>;
}

final _dummyInsurance = Insurance(
  id: 'dummy',
  coupleId: 'c1',
  userId: 'u1',
  name: 'dummy',
  insuranceType: 'LIFE',
  premiumAmount: 0,
  paymentCycle: 'MONTHLY',
  isActive: true,
  visibility: 'SHARED',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

void main() {
  late InsuranceBloc bloc;
  late MockInsuranceRepository mockRepository;

  final tLifeInsurance = Insurance(
    id: 'i1',
    coupleId: 'c1',
    userId: 'u1',
    name: '삼성생명 종신보험',
    insurer: '삼성생명',
    insuranceType: 'LIFE',
    premiumAmount: 150000,
    paymentDay: 25,
    paymentCycle: 'MONTHLY',
    isActive: true,
    visibility: 'SHARED',
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
    updatedAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tCarInsurance = Insurance(
    id: 'i2',
    coupleId: 'c1',
    userId: 'u1',
    name: '현대해상 자동차보험',
    insurer: '현대해상',
    insuranceType: 'CAR',
    premiumAmount: 80000,
    paymentDay: 10,
    paymentCycle: 'MONTHLY',
    isActive: true,
    visibility: 'SHARED',
    createdAt: DateTime.parse('2024-02-01T12:00:00Z'),
    updatedAt: DateTime.parse('2024-02-01T12:00:00Z'),
  );

  final tInsurances = [tLifeInsurance, tCarInsurance];

  const tSummary = InsuranceSummary(
    year: 2026,
    month: 3,
    totalPremium: 230000,
    activeCount: 2,
    items: [
      InsuranceSummaryItem(
        id: 'i1',
        name: '삼성생명 종신보험',
        insuranceType: 'LIFE',
        premiumAmount: 150000,
        paymentCycle: 'MONTHLY',
        paymentDay: 25,
        isActive: true,
      ),
      InsuranceSummaryItem(
        id: 'i2',
        name: '현대해상 자동차보험',
        insuranceType: 'CAR',
        premiumAmount: 80000,
        paymentCycle: 'MONTHLY',
        paymentDay: 10,
        isActive: true,
      ),
    ],
  );

  setUp(() {
    mockRepository = MockInsuranceRepository();
    bloc = InsuranceBloc(insuranceRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('InsuranceBloc', () {
    test('initial state is InsuranceInitial', () {
      expect(bloc.state, const InsuranceInitial());
    });

    group('LoadInsurances', () {
      blocTest<InsuranceBloc, InsuranceState>(
        'emits [Loading, Loaded] on success',
        build: () {
          when(mockRepository.getInsurances())
              .thenAnswer((_) async => Right(tInsurances));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadInsurances()),
        expect: () => [
          const InsuranceLoading(),
          InsuranceLoaded(insurances: tInsurances),
        ],
      );

      blocTest<InsuranceBloc, InsuranceState>(
        'emits [Loading, Loaded] with active filter',
        build: () {
          when(mockRepository.getInsurances(active: true))
              .thenAnswer((_) async => Right(tInsurances));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadInsurances(activeOnly: true)),
        expect: () => [
          const InsuranceLoading(),
          InsuranceLoaded(insurances: tInsurances),
        ],
      );

      blocTest<InsuranceBloc, InsuranceState>(
        'emits [Loading, Error] on failure',
        build: () {
          when(mockRepository.getInsurances()).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('보험 목록을 불러오지 못했습니다')));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadInsurances()),
        expect: () => [
          const InsuranceLoading(),
          const InsuranceError('보험 목록을 불러오지 못했습니다'),
        ],
      );
    });

    group('LoadInsuranceSummary', () {
      blocTest<InsuranceBloc, InsuranceState>(
        'emits [Loaded with summary] when already loaded',
        build: () {
          when(mockRepository.getInsuranceSummary(year: 2026, month: 3))
              .thenAnswer((_) async => const Right(tSummary));
          return bloc;
        },
        seed: () => InsuranceLoaded(insurances: tInsurances),
        act: (bloc) => bloc
            .add(const LoadInsuranceSummary(year: 2026, month: 3)),
        expect: () => [
          InsuranceLoaded(insurances: tInsurances, summary: tSummary),
        ],
      );
    });

    group('DeleteInsurance', () {
      blocTest<InsuranceBloc, InsuranceState>(
        'emits [Loaded] with insurance removed from list',
        build: () {
          when(mockRepository.deleteInsurance('i1'))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () => InsuranceLoaded(insurances: tInsurances),
        act: (bloc) => bloc.add(const DeleteInsurance('i1')),
        expect: () => [
          InsuranceLoaded(
            insurances: [tCarInsurance],
            operationSuccess: '보험이 삭제되었습니다',
          ),
        ],
      );

      blocTest<InsuranceBloc, InsuranceState>(
        'emits [Loaded with operationError] on failure',
        build: () {
          when(mockRepository.deleteInsurance('i1')).thenAnswer((_) async =>
              const Left(ServerFailure('보험을 삭제하지 못했습니다')));
          return bloc;
        },
        seed: () => InsuranceLoaded(insurances: tInsurances),
        act: (bloc) => bloc.add(const DeleteInsurance('i1')),
        expect: () => [
          InsuranceLoaded(
            insurances: tInsurances,
            operationError: '보험을 삭제하지 못했습니다',
          ),
        ],
      );
    });

    group('CreateInsurance', () {
      final tNewInsurance = Insurance(
        id: 'i3',
        coupleId: 'c1',
        userId: 'u1',
        name: '건강보험',
        insuranceType: 'HEALTH',
        premiumAmount: 50000,
        paymentCycle: 'MONTHLY',
        isActive: true,
        visibility: 'SHARED',
        createdAt: DateTime.parse('2024-03-01T12:00:00Z'),
        updatedAt: DateTime.parse('2024-03-01T12:00:00Z'),
      );

      blocTest<InsuranceBloc, InsuranceState>(
        'reloads list on success',
        build: () {
          when(mockRepository.createInsurance(
            name: '건강보험',
            insuranceType: 'HEALTH',
            premiumAmount: 50000,
          )).thenAnswer((_) async => Right(tNewInsurance));
          // After create, LoadInsurances is dispatched
          when(mockRepository.getInsurances())
              .thenAnswer((_) async => Right([...tInsurances, tNewInsurance]));
          return bloc;
        },
        seed: () => InsuranceLoaded(insurances: tInsurances),
        act: (bloc) => bloc.add(const CreateInsurance(
          name: '건강보험',
          insuranceType: 'HEALTH',
          premiumAmount: 50000,
        )),
        expect: () => [
          const InsuranceLoading(),
          InsuranceLoaded(insurances: [...tInsurances, tNewInsurance]),
        ],
      );

      blocTest<InsuranceBloc, InsuranceState>(
        'emits [Loaded with operationError] on failure',
        build: () {
          when(mockRepository.createInsurance(
            name: '건강보험',
            insuranceType: 'HEALTH',
            premiumAmount: 50000,
          )).thenAnswer((_) async =>
              const Left(ServerFailure('보험을 등록하지 못했습니다')));
          return bloc;
        },
        seed: () => InsuranceLoaded(insurances: tInsurances),
        act: (bloc) => bloc.add(const CreateInsurance(
          name: '건강보험',
          insuranceType: 'HEALTH',
          premiumAmount: 50000,
        )),
        expect: () => [
          InsuranceLoaded(
            insurances: tInsurances,
            operationError: '보험을 등록하지 못했습니다',
          ),
        ],
      );
    });
  });

  group('InsuranceLoaded helpers', () {
    test('groupedByType groups insurances by type', () {
      final state = InsuranceLoaded(insurances: tInsurances);
      final grouped = state.groupedByType;
      expect(grouped.keys.length, 2);
      expect(grouped['LIFE']!.length, 1);
      expect(grouped['CAR']!.length, 1);
    });

    test('activeInsurances filters active only', () {
      final inactive = Insurance(
        id: 'i3',
        coupleId: 'c1',
        userId: 'u1',
        name: '해지된 보험',
        insuranceType: 'OTHER',
        premiumAmount: 10000,
        paymentCycle: 'MONTHLY',
        isActive: false,
        visibility: 'SHARED',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final state =
          InsuranceLoaded(insurances: [...tInsurances, inactive]);
      expect(state.activeInsurances, tInsurances);
      expect(state.inactiveInsurances, [inactive]);
    });
  });

  group('Insurance entity', () {
    test('equatable compares by all props', () {
      final copy = Insurance(
        id: 'i1',
        coupleId: 'c1',
        userId: 'u1',
        name: '삼성생명 종신보험',
        insurer: '삼성생명',
        insuranceType: 'LIFE',
        premiumAmount: 150000,
        paymentDay: 25,
        paymentCycle: 'MONTHLY',
        isActive: true,
        visibility: 'SHARED',
        createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T12:00:00Z'),
      );
      expect(tLifeInsurance, equals(copy));
    });
  });
}
