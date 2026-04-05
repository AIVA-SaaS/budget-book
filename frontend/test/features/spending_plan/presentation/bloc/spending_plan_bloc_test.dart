import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_bloc.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_event.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_state.dart';
import 'package:budget_book/features/spending_plan/domain/repositories/spending_plan_repository.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';
import 'package:budget_book/core/error/failure.dart';

class MockSpendingPlanRepository extends Mock
    implements SpendingPlanRepository {
  @override
  Future<Either<Failure, SpendingPlanListResponse>> getSpendingPlans({
    String? startDate,
    String? endDate,
    String? status,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getSpendingPlans, [],
            {#startDate: startDate, #endDate: endDate, #status: status}),
        returnValue: Future.value(
          const Right<Failure, SpendingPlanListResponse>(
            SpendingPlanListResponse(plans: [], summary: _emptySummary),
          ),
        ),
      ) as Future<Either<Failure, SpendingPlanListResponse>>;

  @override
  Future<Either<Failure, SpendingPlan>> createSpendingPlan({
    required String name,
    required int amount,
    required String targetDate,
    String? memo,
    String? categoryId,
    String? paymentMethodId,
    String? budgetId,
    bool isRecurring = false,
    String? frequency,
    String visibility = 'SHARED',
    String? status,
    String? priority,
    int? estimatedMin,
    int? estimatedMax,
    String? tags,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createSpendingPlan, [], {
          #name: name,
          #amount: amount,
          #targetDate: targetDate,
          #memo: memo,
          #categoryId: categoryId,
          #paymentMethodId: paymentMethodId,
          #budgetId: budgetId,
          #isRecurring: isRecurring,
          #frequency: frequency,
          #visibility: visibility,
          #status: status,
          #priority: priority,
          #estimatedMin: estimatedMin,
          #estimatedMax: estimatedMax,
          #tags: tags,
        }),
        returnValue: Future.value(
          const Right<Failure, SpendingPlan>(_dummyPlan),
        ),
      ) as Future<Either<Failure, SpendingPlan>>;

  @override
  Future<Either<Failure, SpendingPlan>> updateSpendingPlan({
    required String id,
    String? name,
    int? amount,
    String? targetDate,
    String? memo,
    bool clearMemo = false,
    String? categoryId,
    bool clearCategoryId = false,
    String? paymentMethodId,
    bool clearPaymentMethodId = false,
    String? budgetId,
    bool clearBudgetId = false,
    bool? isRecurring,
    String? frequency,
    bool clearFrequency = false,
    String? visibility,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateSpendingPlan, [], {
          #id: id,
          #name: name,
          #amount: amount,
          #targetDate: targetDate,
          #memo: memo,
          #clearMemo: clearMemo,
          #categoryId: categoryId,
          #clearCategoryId: clearCategoryId,
          #paymentMethodId: paymentMethodId,
          #clearPaymentMethodId: clearPaymentMethodId,
          #budgetId: budgetId,
          #clearBudgetId: clearBudgetId,
          #isRecurring: isRecurring,
          #frequency: frequency,
          #clearFrequency: clearFrequency,
          #visibility: visibility,
        }),
        returnValue: Future.value(
          const Right<Failure, SpendingPlan>(_dummyPlan),
        ),
      ) as Future<Either<Failure, SpendingPlan>>;

  @override
  Future<Either<Failure, void>> deleteSpendingPlan(String id) =>
      super.noSuchMethod(
        Invocation.method(#deleteSpendingPlan, [id]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, SpendingPlan>> completePlan({
    required String id,
    String? transactionId,
    int? actualAmount,
  }) =>
      super.noSuchMethod(
        Invocation.method(#completePlan, [], {
          #id: id,
          #transactionId: transactionId,
          #actualAmount: actualAmount,
        }),
        returnValue: Future.value(
          const Right<Failure, SpendingPlan>(_dummyPlan),
        ),
      ) as Future<Either<Failure, SpendingPlan>>;

  @override
  Future<Either<Failure, SpendingPlan>> skipPlan(String id) =>
      super.noSuchMethod(
        Invocation.method(#skipPlan, [id]),
        returnValue: Future.value(
          const Right<Failure, SpendingPlan>(_dummyPlan),
        ),
      ) as Future<Either<Failure, SpendingPlan>>;

  @override
  Future<Either<Failure, List<SpendingPlanSuggestion>>> getSuggestions({
    String? categoryId,
    int? amount,
    String? date,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getSuggestions, [],
            {#categoryId: categoryId, #amount: amount, #date: date}),
        returnValue: Future.value(
          const Right<Failure, List<SpendingPlanSuggestion>>([]),
        ),
      ) as Future<Either<Failure, List<SpendingPlanSuggestion>>>;

  @override
  Future<Either<Failure, List<SpendingPlan>>> getWishlist() =>
      super.noSuchMethod(
        Invocation.method(#getWishlist, []),
        returnValue: Future.value(
          const Right<Failure, List<SpendingPlan>>([]),
        ),
      ) as Future<Either<Failure, List<SpendingPlan>>>;

  @override
  Future<Either<Failure, SpendingPlan>> assignPlan({
    required String id,
    required String targetDate,
    int? weekNumber,
    String? budgetId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#assignPlan, [], {
          #id: id,
          #targetDate: targetDate,
          #weekNumber: weekNumber,
          #budgetId: budgetId,
        }),
        returnValue: Future.value(
          const Right<Failure, SpendingPlan>(_dummyPlan),
        ),
      ) as Future<Either<Failure, SpendingPlan>>;

  @override
  Future<Either<Failure, SpendingPlan>> completeWithTransaction({
    required String id,
    required int amount,
    required String transactionDate,
    String? description,
    String? categoryId,
    String? paymentMethodId,
    String? linkedTransactionId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#completeWithTransaction, [], {
          #id: id,
          #amount: amount,
          #transactionDate: transactionDate,
          #description: description,
          #categoryId: categoryId,
          #paymentMethodId: paymentMethodId,
        }),
        returnValue: Future.value(
          const Right<Failure, SpendingPlan>(_dummyPlan),
        ),
      ) as Future<Either<Failure, SpendingPlan>>;
}

const _emptySummary = SpendingPlanSummary(
  totalPlanned: 0,
  totalCompleted: 0,
  totalSkipped: 0,
  plannedCount: 0,
  completedCount: 0,
  overdueCount: 0,
);

const _dummyPlan = SpendingPlan(
  id: 'dummy',
  name: 'dummy',
  amount: 0,
  targetDate: '2026-03-28',
  status: 'PLANNED',
  isRecurring: false,
  visibility: 'SHARED',
  authorName: '',
  createdAt: '',
);

void main() {
  late SpendingPlanBloc bloc;
  late MockSpendingPlanRepository mockRepository;

  const tPlan1 = SpendingPlan(
    id: 'sp1',
    name: '코스트코 장보기',
    amount: 150000,
    targetDate: '2026-03-29',
    categoryId: 'cat1',
    categoryName: '식비',
    status: 'PLANNED',
    isRecurring: false,
    visibility: 'SHARED',
    authorName: '사용자',
    createdAt: '2026-03-25T12:00:00Z',
  );

  const tPlan2 = SpendingPlan(
    id: 'sp2',
    name: '외식',
    amount: 80000,
    targetDate: '2026-03-30',
    categoryId: 'cat1',
    categoryName: '식비',
    status: 'COMPLETED',
    actualAmount: 75000,
    completedDate: '2026-03-30',
    isRecurring: false,
    visibility: 'SHARED',
    authorName: '사용자',
    createdAt: '2026-03-25T12:00:00Z',
  );

  const tPlans = [tPlan1, tPlan2];

  const tSummary = SpendingPlanSummary(
    totalPlanned: 230000,
    totalCompleted: 75000,
    totalSkipped: 0,
    plannedCount: 1,
    completedCount: 1,
    overdueCount: 0,
  );

  const tListResponse = SpendingPlanListResponse(
    plans: tPlans,
    summary: tSummary,
  );

  setUp(() {
    mockRepository = MockSpendingPlanRepository();
    bloc = SpendingPlanBloc(spendingPlanRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('SpendingPlanBloc', () {
    test('initial state is SpendingPlanInitial', () {
      expect(bloc.state, const SpendingPlanInitial());
    });

    group('LoadSpendingPlans', () {
      blocTest<SpendingPlanBloc, SpendingPlanState>(
        'emits [Loaded] on success (no loading state to preserve previous data)',
        build: () {
          when(mockRepository.getSpendingPlans(
            startDate: '2026-03-01',
            endDate: '2026-03-31',
          )).thenAnswer((_) async => const Right(tListResponse));
          when(mockRepository.getWishlist())
              .thenAnswer((_) async => const Right(<SpendingPlan>[]));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadSpendingPlans(
          startDate: '2026-03-01',
          endDate: '2026-03-31',
        )),
        expect: () => [
          const SpendingPlanLoaded(
              plans: tPlans, summary: tSummary, wishlist: []),
        ],
      );

      blocTest<SpendingPlanBloc, SpendingPlanState>(
        'emits [Loaded] with status filter',
        build: () {
          when(mockRepository.getSpendingPlans(
            startDate: '2026-03-01',
            endDate: '2026-03-31',
            status: 'PLANNED',
          )).thenAnswer((_) async => const Right(SpendingPlanListResponse(
                plans: [tPlan1],
                summary: tSummary,
              )));
          when(mockRepository.getWishlist())
              .thenAnswer((_) async => const Right(<SpendingPlan>[]));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadSpendingPlans(
          startDate: '2026-03-01',
          endDate: '2026-03-31',
          status: 'PLANNED',
        )),
        expect: () => [
          const SpendingPlanLoaded(
              plans: [tPlan1], summary: tSummary, wishlist: []),
        ],
      );

      blocTest<SpendingPlanBloc, SpendingPlanState>(
        'emits [Error] on failure',
        build: () {
          when(mockRepository.getSpendingPlans())
              .thenAnswer((_) async =>
                  const Left(ServerFailure('지출 계획을 불러오지 못했습니다')));
          when(mockRepository.getWishlist())
              .thenAnswer((_) async => const Right(<SpendingPlan>[]));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadSpendingPlans()),
        expect: () => [
          const SpendingPlanError('지출 계획을 불러오지 못했습니다'),
        ],
      );
    });

    group('DeleteSpendingPlan', () {
      blocTest<SpendingPlanBloc, SpendingPlanState>(
        'emits [Loaded] with plan removed from list',
        build: () {
          when(mockRepository.deleteSpendingPlan('sp1'))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () =>
            const SpendingPlanLoaded(plans: tPlans, summary: tSummary),
        act: (bloc) => bloc.add(const DeleteSpendingPlan('sp1')),
        expect: () => [
          const SpendingPlanLoaded(
            plans: [tPlan2],
            summary: tSummary,
            operationSuccess: '지출 계획이 삭제되었습니다',
          ),
        ],
      );

      blocTest<SpendingPlanBloc, SpendingPlanState>(
        'emits [Loaded with operationError] on failure',
        build: () {
          when(mockRepository.deleteSpendingPlan('sp1')).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('지출 계획을 삭제하지 못했습니다')));
          return bloc;
        },
        seed: () =>
            const SpendingPlanLoaded(plans: tPlans, summary: tSummary),
        act: (bloc) => bloc.add(const DeleteSpendingPlan('sp1')),
        expect: () => [
          const SpendingPlanLoaded(
            plans: tPlans,
            summary: tSummary,
            operationError: '지출 계획을 삭제하지 못했습니다',
          ),
        ],
      );
    });

    group('CreateSpendingPlan', () {
      blocTest<SpendingPlanBloc, SpendingPlanState>(
        'reloads list on success',
        build: () {
          when(mockRepository.createSpendingPlan(
            name: '새 계획',
            amount: 50000,
            targetDate: '2026-04-01',
          )).thenAnswer((_) async => const Right(_dummyPlan));
          // After create, LoadSpendingPlans is dispatched (with no filters)
          when(mockRepository.getSpendingPlans())
              .thenAnswer((_) async => const Right(tListResponse));
          when(mockRepository.getWishlist())
              .thenAnswer((_) async => const Right(<SpendingPlan>[]));
          return bloc;
        },
        seed: () =>
            const SpendingPlanLoaded(plans: tPlans, summary: tSummary),
        act: (bloc) => bloc.add(const CreateSpendingPlan(
          name: '새 계획',
          amount: 50000,
          targetDate: '2026-04-01',
        )),
        expect: () => [
          const SpendingPlanLoaded(
              plans: tPlans, summary: tSummary, wishlist: []),
        ],
      );

      blocTest<SpendingPlanBloc, SpendingPlanState>(
        'emits [Loaded with operationError] on failure',
        build: () {
          when(mockRepository.createSpendingPlan(
            name: '새 계획',
            amount: 50000,
            targetDate: '2026-04-01',
          )).thenAnswer((_) async =>
              const Left(ServerFailure('지출 계획을 등록하지 못했습니다')));
          return bloc;
        },
        seed: () =>
            const SpendingPlanLoaded(plans: tPlans, summary: tSummary),
        act: (bloc) => bloc.add(const CreateSpendingPlan(
          name: '새 계획',
          amount: 50000,
          targetDate: '2026-04-01',
        )),
        expect: () => [
          const SpendingPlanLoaded(
            plans: tPlans,
            summary: tSummary,
            operationError: '지출 계획을 등록하지 못했습니다',
          ),
        ],
      );
    });

    group('SkipPlan', () {
      blocTest<SpendingPlanBloc, SpendingPlanState>(
        'emits [Loaded with operationError] on failure',
        build: () {
          when(mockRepository.skipPlan('sp1')).thenAnswer((_) async =>
              const Left(ServerFailure('계획 건너뛰기에 실패했습니다')));
          return bloc;
        },
        seed: () =>
            const SpendingPlanLoaded(plans: tPlans, summary: tSummary),
        act: (bloc) => bloc.add(const SkipPlan('sp1')),
        expect: () => [
          const SpendingPlanLoaded(
            plans: tPlans,
            summary: tSummary,
            operationError: '계획 건너뛰기에 실패했습니다',
          ),
        ],
      );
    });
  });

    group('LoadWishlist', () {
      const tWishlistItem = SpendingPlan(
        id: 'wl1',
        name: '에어팟 프로',
        amount: 350000,
        status: 'WISHLIST',
        priority: 'HIGH',
        estimatedMin: 300000,
        estimatedMax: 380000,
        tags: ['전자기기', '선물'],
        isRecurring: false,
        visibility: 'SHARED',
        authorName: '사용자',
        createdAt: '2026-03-25T12:00:00Z',
      );

      blocTest<SpendingPlanBloc, SpendingPlanState>(
        'emits Loaded with wishlist on success when already loaded',
        build: () {
          when(mockRepository.getWishlist())
              .thenAnswer((_) async => const Right([tWishlistItem]));
          return bloc;
        },
        seed: () =>
            const SpendingPlanLoaded(plans: tPlans, summary: tSummary),
        act: (bloc) => bloc.add(const LoadWishlist()),
        expect: () => [
          const SpendingPlanLoaded(
            plans: tPlans,
            summary: tSummary,
            wishlist: [tWishlistItem],
          ),
        ],
      );

      blocTest<SpendingPlanBloc, SpendingPlanState>(
        'emits Loaded with empty plans when not yet loaded',
        build: () {
          when(mockRepository.getWishlist())
              .thenAnswer((_) async => const Right([tWishlistItem]));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadWishlist()),
        expect: () => [
          const SpendingPlanLoaded(
            plans: [],
            summary: _emptySummary,
            wishlist: [tWishlistItem],
          ),
        ],
      );

      blocTest<SpendingPlanBloc, SpendingPlanState>(
        'emits operationError on failure when loaded',
        build: () {
          when(mockRepository.getWishlist()).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('구매 목록을 불러오지 못했습니다')));
          return bloc;
        },
        seed: () =>
            const SpendingPlanLoaded(plans: tPlans, summary: tSummary),
        act: (bloc) => bloc.add(const LoadWishlist()),
        expect: () => [
          const SpendingPlanLoaded(
            plans: tPlans,
            summary: tSummary,
            operationError: '구매 목록을 불러오지 못했습니다',
          ),
        ],
      );
    });

  group('SpendingPlanLoaded helpers', () {
    test('groupedByDate groups plans by date', () {
      const state = SpendingPlanLoaded(plans: tPlans, summary: tSummary);
      final grouped = state.groupedByDate;
      expect(grouped.keys.length, 2);
      expect(grouped['2026-03-29']!.length, 1);
      expect(grouped['2026-03-30']!.length, 1);
    });

    test('status-filtered lists work correctly', () {
      const state = SpendingPlanLoaded(plans: tPlans, summary: tSummary);
      expect(state.plannedPlans.length, 1);
      expect(state.completedPlans.length, 1);
      expect(state.skippedPlans.length, 0);
      expect(state.overduePlans.length, 0);
    });

    test('wishlistByPriority groups by priority order', () {
      const wlHigh = SpendingPlan(
        id: 'wlh', name: 'high', amount: 0,
        status: 'WISHLIST', priority: 'HIGH',
        isRecurring: false, visibility: 'SHARED',
        authorName: '', createdAt: '',
      );
      const wlMed = SpendingPlan(
        id: 'wlm', name: 'med', amount: 0,
        status: 'WISHLIST', priority: 'MEDIUM',
        isRecurring: false, visibility: 'SHARED',
        authorName: '', createdAt: '',
      );
      const wlLow = SpendingPlan(
        id: 'wll', name: 'low', amount: 0,
        status: 'WISHLIST', priority: 'LOW',
        isRecurring: false, visibility: 'SHARED',
        authorName: '', createdAt: '',
      );
      const state = SpendingPlanLoaded(
        plans: tPlans,
        summary: tSummary,
        wishlist: [wlMed, wlHigh, wlLow],
      );
      final grouped = state.wishlistByPriority;
      expect(grouped.keys.toList(), ['HIGH', 'MEDIUM', 'LOW']);
      expect(grouped['HIGH']!.length, 1);
      expect(grouped['MEDIUM']!.length, 1);
      expect(grouped['LOW']!.length, 1);
    });
  });

  group('SpendingPlan entity', () {
    test('variance is computed correctly', () {
      expect(tPlan1.variance, isNull);
      expect(tPlan2.variance, -5000); // 75000 - 80000 = -5000
    });

    test('equatable compares by all props', () {
      const copy = SpendingPlan(
        id: 'sp1',
        name: '코스트코 장보기',
        amount: 150000,
        targetDate: '2026-03-29',
        categoryId: 'cat1',
        categoryName: '식비',
        status: 'PLANNED',
        isRecurring: false,
        visibility: 'SHARED',
        authorName: '사용자',
        createdAt: '2026-03-25T12:00:00Z',
      );
      expect(tPlan1, equals(copy));
    });

    test('isWishlist returns true for WISHLIST status', () {
      const wishlist = SpendingPlan(
        id: 'wl1',
        name: 'test',
        amount: 0,
        status: 'WISHLIST',
        isRecurring: false,
        visibility: 'SHARED',
        authorName: '',
        createdAt: '',
      );
      expect(wishlist.isWishlist, true);
      expect(tPlan1.isWishlist, false);
    });

    test('priceRangeText formats correctly', () {
      const withRange = SpendingPlan(
        id: 'wl1',
        name: 'test',
        amount: 0,
        status: 'WISHLIST',
        estimatedMin: 300000,
        estimatedMax: 380000,
        isRecurring: false,
        visibility: 'SHARED',
        authorName: '',
        createdAt: '',
      );
      expect(withRange.priceRangeText, '300,000~380,000원');

      const withAmount = SpendingPlan(
        id: 'wl2',
        name: 'test',
        amount: 150000,
        status: 'WISHLIST',
        isRecurring: false,
        visibility: 'SHARED',
        authorName: '',
        createdAt: '',
      );
      expect(withAmount.priceRangeText, '150,000원');

      const noPrice = SpendingPlan(
        id: 'wl3',
        name: 'test',
        amount: 0,
        status: 'WISHLIST',
        isRecurring: false,
        visibility: 'SHARED',
        authorName: '',
        createdAt: '',
      );
      expect(noPrice.priceRangeText, '미정');
    });
  });

  group('SpendingPlanSummary', () {
    test('totalCount sums planned + completed + overdue', () {
      expect(tSummary.totalCount, 2);
    });
  });
}
