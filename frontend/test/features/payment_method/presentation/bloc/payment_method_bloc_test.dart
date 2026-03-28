import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/payment_method/domain/repositories/payment_method_repository.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/domain/entities/card_pending.dart';
import 'package:budget_book/features/payment_method/domain/entities/card_settlement_summary.dart';
import 'package:budget_book/core/error/failure.dart';

class MockPaymentMethodRepository extends Mock
    implements PaymentMethodRepository {
  @override
  Future<Either<Failure, List<PaymentMethod>>> getPaymentMethods() =>
      super.noSuchMethod(
        Invocation.method(#getPaymentMethods, []),
        returnValue: Future.value(
          const Right<Failure, List<PaymentMethod>>([]),
        ),
      ) as Future<Either<Failure, List<PaymentMethod>>>;

  @override
  Future<Either<Failure, PaymentMethod>> createPaymentMethod({
    required String name,
    required String type,
    int? settlementDay,
    int? closingDay,
    String? linkedBankId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createPaymentMethod, [], {
          #name: name,
          #type: type,
          #settlementDay: settlementDay,
          #closingDay: closingDay,
          #linkedBankId: linkedBankId,
        }),
        returnValue: Future.value(
          Right<Failure, PaymentMethod>(PaymentMethod(
            id: '',
            name: '',
            type: 'CASH',
            isActive: true,
            isDefault: false,
            displayOrder: 0,
            createdAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, PaymentMethod>>;

  @override
  Future<Either<Failure, PaymentMethod>> updatePaymentMethod({
    required String id,
    String? name,
    int? settlementDay,
    int? closingDay,
    bool? isActive,
    int? displayOrder,
    String? linkedBankId,
    bool clearLinkedBank = false,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updatePaymentMethod, [], {
          #id: id,
          #name: name,
          #settlementDay: settlementDay,
          #closingDay: closingDay,
          #isActive: isActive,
          #displayOrder: displayOrder,
          #linkedBankId: linkedBankId,
          #clearLinkedBank: clearLinkedBank,
        }),
        returnValue: Future.value(
          Right<Failure, PaymentMethod>(PaymentMethod(
            id: '',
            name: '',
            type: 'CASH',
            isActive: true,
            isDefault: false,
            displayOrder: 0,
            createdAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, PaymentMethod>>;

  @override
  Future<Either<Failure, void>> deletePaymentMethod(String id) =>
      super.noSuchMethod(
        Invocation.method(#deletePaymentMethod, [id]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, List<CardPending>>> getCardPending(
          int year, int month) =>
      super.noSuchMethod(
        Invocation.method(#getCardPending, [year, month]),
        returnValue: Future.value(
          const Right<Failure, List<CardPending>>([]),
        ),
      ) as Future<Either<Failure, List<CardPending>>>;

  @override
  Future<Either<Failure, void>> reorderPaymentMethods(
          List<String> orderedIds) =>
      super.noSuchMethod(
        Invocation.method(#reorderPaymentMethods, [orderedIds]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, CardSettlementSummary>>
      getCardSettlementSummary() =>
          super.noSuchMethod(
            Invocation.method(#getCardSettlementSummary, []),
            returnValue: Future.value(
              const Right<Failure, CardSettlementSummary>(
                CardSettlementSummary(
                  previousMonth: CardSettlementMonth(
                    year: 2026,
                    month: 2,
                    totalAmount: 0,
                    cards: [],
                  ),
                  currentMonth: CardSettlementMonth(
                    year: 2026,
                    month: 3,
                    totalAmount: 0,
                    cards: [],
                  ),
                ),
              ),
            ),
          ) as Future<Either<Failure, CardSettlementSummary>>;
}

void main() {
  late PaymentMethodBloc bloc;
  late MockPaymentMethodRepository mockRepository;

  final tCashMethod = PaymentMethod(
    id: 'pm-1',
    name: '현금',
    type: 'CASH',
    isActive: true,
    isDefault: true,
    displayOrder: 0,
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tCreditMethod = PaymentMethod(
    id: 'pm-2',
    name: '신한카드',
    type: 'CREDIT',
    settlementDay: 15,
    closingDay: 25,
    isActive: true,
    isDefault: false,
    displayOrder: 2,
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tNewDebitMethod = PaymentMethod(
    id: 'pm-3',
    name: '국민체크',
    type: 'DEBIT',
    isActive: true,
    isDefault: false,
    displayOrder: 3,
    createdAt: DateTime.parse('2024-02-01T12:00:00Z'),
  );

  final tMethods = [tCashMethod, tCreditMethod];

  final tCardPending = CardPending(
    paymentMethod: tCreditMethod,
    pendingAmount: 450000,
    settlementDate: '2026-04-15',
    transactionCount: 12,
  );

  setUp(() {
    mockRepository = MockPaymentMethodRepository();
    bloc = PaymentMethodBloc(paymentMethodRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('PaymentMethodBloc', () {
    test('initial state is PaymentMethodInitial', () {
      expect(bloc.state, const PaymentMethodInitial());
    });

    group('LoadPaymentMethods', () {
      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'emits [PaymentMethodLoading, PaymentMethodLoaded] on success',
        build: () {
          when(mockRepository.getPaymentMethods())
              .thenAnswer((_) async => Right(tMethods));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadPaymentMethods()),
        expect: () => [
          const PaymentMethodLoading(),
          PaymentMethodLoaded(tMethods),
        ],
      );

      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'emits [PaymentMethodLoading, PaymentMethodError] on failure',
        build: () {
          when(mockRepository.getPaymentMethods()).thenAnswer((_) async =>
              const Left(
                  ServerFailure('Failed to load payment methods')));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadPaymentMethods()),
        expect: () => [
          const PaymentMethodLoading(),
          const PaymentMethodError('Failed to load payment methods'),
        ],
      );
    });

    group('CreatePaymentMethod', () {
      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'emits [PaymentMethodLoaded] with new method appended',
        build: () {
          when(mockRepository.createPaymentMethod(
            name: '국민체크',
            type: 'DEBIT',
            settlementDay: null,
            closingDay: null,
            linkedBankId: null,
          )).thenAnswer((_) async => Right(tNewDebitMethod));
          return bloc;
        },
        seed: () => PaymentMethodLoaded(tMethods),
        act: (bloc) => bloc.add(const CreatePaymentMethod(
          name: '국민체크',
          type: 'DEBIT',
        )),
        expect: () => [
          PaymentMethodLoaded([...tMethods, tNewDebitMethod]),
        ],
      );

      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'emits [PaymentMethodLoaded with operationError] on failure',
        build: () {
          when(mockRepository.createPaymentMethod(
            name: '국민체크',
            type: 'DEBIT',
            settlementDay: null,
            closingDay: null,
            linkedBankId: null,
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to create payment method')));
          return bloc;
        },
        seed: () => PaymentMethodLoaded(tMethods),
        act: (bloc) => bloc.add(const CreatePaymentMethod(
          name: '국민체크',
          type: 'DEBIT',
        )),
        expect: () => [
          PaymentMethodLoaded(tMethods,
              operationError: 'Failed to create payment method'),
        ],
      );

      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'creates credit card with settlement and closing days',
        build: () {
          final newCredit = PaymentMethod(
            id: 'pm-4',
            name: '삼성카드',
            type: 'CREDIT',
            settlementDay: 10,
            closingDay: 20,
            isActive: true,
            isDefault: false,
            displayOrder: 4,
            createdAt: DateTime.parse('2024-02-01T12:00:00Z'),
          );
          when(mockRepository.createPaymentMethod(
            name: '삼성카드',
            type: 'CREDIT',
            settlementDay: 10,
            closingDay: 20,
            linkedBankId: null,
          )).thenAnswer((_) async => Right(newCredit));
          return bloc;
        },
        seed: () => PaymentMethodLoaded(tMethods),
        act: (bloc) => bloc.add(const CreatePaymentMethod(
          name: '삼성카드',
          type: 'CREDIT',
          settlementDay: 10,
          closingDay: 20,
        )),
        expect: () => [
          isA<PaymentMethodLoaded>().having(
            (s) => s.paymentMethods.length,
            'has 3 methods',
            3,
          ),
        ],
      );
    });

    group('UpdatePaymentMethod', () {
      final tUpdatedMethod = PaymentMethod(
        id: 'pm-2',
        name: '신한카드 (변경)',
        type: 'CREDIT',
        settlementDay: 20,
        closingDay: 25,
        isActive: true,
        isDefault: false,
        displayOrder: 2,
        createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
      );

      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'emits [PaymentMethodLoaded] with updated method in list',
        build: () {
          when(mockRepository.updatePaymentMethod(
            id: 'pm-2',
            name: '신한카드 (변경)',
            settlementDay: 20,
            clearLinkedBank: false,
          )).thenAnswer((_) async => Right(tUpdatedMethod));
          return bloc;
        },
        seed: () => PaymentMethodLoaded(tMethods),
        act: (bloc) => bloc.add(const UpdatePaymentMethod(
          id: 'pm-2',
          name: '신한카드 (변경)',
          settlementDay: 20,
        )),
        expect: () => [
          PaymentMethodLoaded([tCashMethod, tUpdatedMethod]),
        ],
      );

      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'emits [PaymentMethodLoaded with operationError] on failure',
        build: () {
          when(mockRepository.updatePaymentMethod(
            id: 'pm-2',
            name: '신한카드 (변경)',
            clearLinkedBank: false,
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to update payment method')));
          return bloc;
        },
        seed: () => PaymentMethodLoaded(tMethods),
        act: (bloc) => bloc.add(const UpdatePaymentMethod(
          id: 'pm-2',
          name: '신한카드 (변경)',
        )),
        expect: () => [
          PaymentMethodLoaded(tMethods,
              operationError: 'Failed to update payment method'),
        ],
      );
    });

    group('DeletePaymentMethod', () {
      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'emits [PaymentMethodLoaded] with method removed',
        build: () {
          when(mockRepository.deletePaymentMethod('pm-2'))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () => PaymentMethodLoaded(tMethods),
        act: (bloc) => bloc.add(const DeletePaymentMethod('pm-2')),
        expect: () => [
          PaymentMethodLoaded([tCashMethod]),
        ],
      );

      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'emits [PaymentMethodLoaded with operationError] on failure',
        build: () {
          when(mockRepository.deletePaymentMethod('pm-1')).thenAnswer(
              (_) async => const Left(
                  ServerFailure('Default payment methods cannot be deleted')));
          return bloc;
        },
        seed: () => PaymentMethodLoaded(tMethods),
        act: (bloc) => bloc.add(const DeletePaymentMethod('pm-1')),
        expect: () => [
          PaymentMethodLoaded(tMethods,
              operationError:
                  'Default payment methods cannot be deleted'),
        ],
      );
    });

    group('ReorderPaymentMethods', () {
      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'emits [PaymentMethodLoaded] with reordered methods on success',
        build: () {
          when(mockRepository.reorderPaymentMethods(['pm-2', 'pm-1']))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () => PaymentMethodLoaded(tMethods),
        act: (bloc) =>
            bloc.add(const ReorderPaymentMethods(['pm-2', 'pm-1'])),
        expect: () => [
          PaymentMethodLoaded([tCreditMethod, tCashMethod]),
        ],
      );

      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'rolls back on failure',
        build: () {
          when(mockRepository.reorderPaymentMethods(['pm-2', 'pm-1']))
              .thenAnswer((_) async => const Left(
                  ServerFailure('Failed to reorder payment methods')));
          return bloc;
        },
        seed: () => PaymentMethodLoaded(tMethods),
        act: (bloc) =>
            bloc.add(const ReorderPaymentMethods(['pm-2', 'pm-1'])),
        expect: () => [
          // First: optimistic update
          PaymentMethodLoaded([tCreditMethod, tCashMethod]),
          // Then: rollback
          PaymentMethodLoaded(tMethods,
              operationError: 'Failed to reorder payment methods'),
        ],
      );
    });

    group('LoadCardPending', () {
      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'emits [PaymentMethodLoaded] with card pendings',
        build: () {
          when(mockRepository.getCardPending(2026, 3))
              .thenAnswer((_) async => Right([tCardPending]));
          return bloc;
        },
        seed: () => PaymentMethodLoaded(tMethods),
        act: (bloc) =>
            bloc.add(const LoadCardPending(year: 2026, month: 3)),
        expect: () => [
          PaymentMethodLoaded(tMethods, cardPendings: [tCardPending]),
        ],
      );

      blocTest<PaymentMethodBloc, PaymentMethodState>(
        'emits [PaymentMethodLoaded with operationError] on failure',
        build: () {
          when(mockRepository.getCardPending(2026, 3)).thenAnswer(
              (_) async =>
                  const Left(ServerFailure('Failed to load card pending info')));
          return bloc;
        },
        seed: () => PaymentMethodLoaded(tMethods),
        act: (bloc) =>
            bloc.add(const LoadCardPending(year: 2026, month: 3)),
        expect: () => [
          PaymentMethodLoaded(tMethods,
              operationError: 'Failed to load card pending info'),
        ],
      );
    });
  });

  group('PaymentMethodLoaded helpers', () {
    test('activePaymentMethods returns only active methods', () {
      final inactiveMethod = PaymentMethod(
        id: 'pm-4',
        name: '비활성',
        type: 'CASH',
        isActive: false,
        isDefault: false,
        displayOrder: 4,
        createdAt: DateTime(2024),
      );
      final state = PaymentMethodLoaded([...tMethods, inactiveMethod]);
      expect(state.activePaymentMethods, tMethods);
    });

    test('creditCards returns only CREDIT type', () {
      final state = PaymentMethodLoaded(tMethods);
      expect(state.creditCards, [tCreditMethod]);
    });
  });

  group('PaymentMethod entity', () {
    test('isCash returns true for CASH type', () {
      expect(tCashMethod.isCash, true);
      expect(tCashMethod.isDebit, false);
      expect(tCashMethod.isCredit, false);
    });

    test('isCredit returns true for CREDIT type', () {
      expect(tCreditMethod.isCash, false);
      expect(tCreditMethod.isDebit, false);
      expect(tCreditMethod.isCredit, true);
    });

    test('isDebit returns true for DEBIT type', () {
      expect(tNewDebitMethod.isCash, false);
      expect(tNewDebitMethod.isDebit, true);
      expect(tNewDebitMethod.isCredit, false);
    });
  });
}
