import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/card_settlement/presentation/bloc/card_settlement_bloc.dart';
import 'package:budget_book/features/card_settlement/presentation/bloc/card_settlement_event.dart';
import 'package:budget_book/features/card_settlement/presentation/bloc/card_settlement_state.dart';
import 'package:budget_book/features/card_settlement/domain/repositories/card_settlement_repository.dart';
import 'package:budget_book/features/card_settlement/domain/entities/settlement_transaction.dart';
import 'package:budget_book/features/transfer/domain/repositories/transfer_repository.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/core/error/failure.dart';

class MockCardSettlementRepository extends Mock
    implements CardSettlementRepository {
  @override
  Future<Either<Failure, SettlementTransactionsResponse>>
      getSettlementTransactions({
    required String paymentMethodId,
    required int year,
    required int month,
  }) =>
          super.noSuchMethod(
            Invocation.method(#getSettlementTransactions, [], {
              #paymentMethodId: paymentMethodId,
              #year: year,
              #month: month,
            }),
            returnValue: Future.value(
              const Right<Failure, SettlementTransactionsResponse>(
                SettlementTransactionsResponse(
                  totalAmount: 0,
                  transactionCount: 0,
                  transactions: [],
                ),
              ),
            ),
          ) as Future<Either<Failure, SettlementTransactionsResponse>>;
}

class MockTransferRepository extends Mock implements TransferRepository {
  @override
  Future<Either<Failure, Transfer>> createTransfer({
    required String sourcePaymentMethodId,
    required String destinationPaymentMethodId,
    required int amount,
    String? description,
    required String transferDate,
    String? memo,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createTransfer, [], {
          #sourcePaymentMethodId: sourcePaymentMethodId,
          #destinationPaymentMethodId: destinationPaymentMethodId,
          #amount: amount,
          #description: description,
          #transferDate: transferDate,
          #memo: memo,
        }),
        returnValue: Future.value(
          Right<Failure, Transfer>(Transfer(
            id: 'new',
            coupleId: 'c1',
            author: const TransactionAuthor(id: 'u1', nickname: 'User'),
            sourcePaymentMethod:
                const PaymentMethodRef(id: 's1', name: 'Bank', type: 'BANK'),
            destinationPaymentMethod:
                const PaymentMethodRef(id: 'd1', name: 'Card', type: 'CREDIT'),
            amount: 100000,
            transferDate: '2026-04-14',
            createdAt: DateTime(2026, 4, 14),
          )),
        ),
      ) as Future<Either<Failure, Transfer>>;

  @override
  Future<Either<Failure, Transfer>> createCardSettlement({
    required String sourcePaymentMethodId,
    required String destinationPaymentMethodId,
    required int amount,
    required String transferDate,
    String? description,
    required List<String> transactionIds,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createCardSettlement, [], {
          #sourcePaymentMethodId: sourcePaymentMethodId,
          #destinationPaymentMethodId: destinationPaymentMethodId,
          #amount: amount,
          #transferDate: transferDate,
          #description: description,
          #transactionIds: transactionIds,
        }),
        returnValue: Future.value(
          Right<Failure, Transfer>(Transfer(
            id: 'new',
            coupleId: 'c1',
            author: const TransactionAuthor(id: 'u1', nickname: 'User'),
            sourcePaymentMethod:
                const PaymentMethodRef(id: 's1', name: 'Bank', type: 'BANK'),
            destinationPaymentMethod:
                const PaymentMethodRef(id: 'd1', name: 'Card', type: 'CREDIT'),
            amount: 100000,
            transferDate: '2026-04-14',
            createdAt: DateTime(2026, 4, 14),
          )),
        ),
      ) as Future<Either<Failure, Transfer>>;
}

void main() {
  late CardSettlementBloc bloc;
  late MockCardSettlementRepository mockSettlementRepo;
  late MockTransferRepository mockTransferRepo;

  const tTx1 = SettlementTransaction(
    id: 'tx-1',
    transactionDate: '2026-03-15',
    description: '편의점',
    amount: 5000,
    categoryName: '식비',
  );

  const tTx2 = SettlementTransaction(
    id: 'tx-2',
    transactionDate: '2026-03-20',
    description: '주유',
    amount: 80000,
    categoryName: '교통',
  );

  const tResponse = SettlementTransactionsResponse(
    totalAmount: 85000,
    transactionCount: 2,
    transactions: [tTx1, tTx2],
  );

  setUp(() {
    mockSettlementRepo = MockCardSettlementRepository();
    mockTransferRepo = MockTransferRepository();
    bloc = CardSettlementBloc(
      cardSettlementRepository: mockSettlementRepo,
      transferRepository: mockTransferRepo,
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('CardSettlementBloc', () {
    test('initial state is CardSettlementInitial', () {
      expect(bloc.state, const CardSettlementInitial());
    });

    group('LoadSettlement', () {
      blocTest<CardSettlementBloc, CardSettlementState>(
        'emits [Loading, Loaded] on success with all transactions selected',
        build: () {
          when(mockSettlementRepo.getSettlementTransactions(
            paymentMethodId: 'card-1',
            year: 2026,
            month: 3,
          )).thenAnswer((_) async => const Right(tResponse));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadSettlement(
          paymentMethodId: 'card-1',
          year: 2026,
          month: 3,
        )),
        expect: () => [
          const CardSettlementLoading(),
          const CardSettlementLoaded(
            transactions: [tTx1, tTx2],
            selectedIds: {'tx-1', 'tx-2'},
            totalAmount: 85000,
          ),
        ],
      );

      blocTest<CardSettlementBloc, CardSettlementState>(
        'emits [Loading, Error] on failure',
        build: () {
          when(mockSettlementRepo.getSettlementTransactions(
            paymentMethodId: 'card-1',
            year: 2026,
            month: 3,
          )).thenAnswer((_) async =>
              const Left(ServerFailure('결제 대상 거래를 불러오지 못했습니다')));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadSettlement(
          paymentMethodId: 'card-1',
          year: 2026,
          month: 3,
        )),
        expect: () => [
          const CardSettlementLoading(),
          const CardSettlementError('결제 대상 거래를 불러오지 못했습니다'),
        ],
      );
    });

    group('ToggleTransaction', () {
      blocTest<CardSettlementBloc, CardSettlementState>(
        'removes transaction from selectedIds when already selected',
        build: () => bloc,
        seed: () => const CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-1', 'tx-2'},
          totalAmount: 85000,
        ),
        act: (bloc) => bloc.add(const ToggleTransaction('tx-1')),
        expect: () => [
          const CardSettlementLoaded(
            transactions: [tTx1, tTx2],
            selectedIds: {'tx-2'},
            totalAmount: 85000,
          ),
        ],
      );

      blocTest<CardSettlementBloc, CardSettlementState>(
        'adds transaction to selectedIds when not selected',
        build: () => bloc,
        seed: () => const CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-2'},
          totalAmount: 85000,
        ),
        act: (bloc) => bloc.add(const ToggleTransaction('tx-1')),
        expect: () => [
          const CardSettlementLoaded(
            transactions: [tTx1, tTx2],
            selectedIds: {'tx-1', 'tx-2'},
            totalAmount: 85000,
          ),
        ],
      );
    });

    group('ToggleAllTransactions', () {
      blocTest<CardSettlementBloc, CardSettlementState>(
        'selects all when true',
        build: () => bloc,
        seed: () => const CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {},
          totalAmount: 85000,
        ),
        act: (bloc) => bloc.add(const ToggleAllTransactions(true)),
        expect: () => [
          const CardSettlementLoaded(
            transactions: [tTx1, tTx2],
            selectedIds: {'tx-1', 'tx-2'},
            totalAmount: 85000,
          ),
        ],
      );

      blocTest<CardSettlementBloc, CardSettlementState>(
        'deselects all when false',
        build: () => bloc,
        seed: () => const CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-1', 'tx-2'},
          totalAmount: 85000,
        ),
        act: (bloc) => bloc.add(const ToggleAllTransactions(false)),
        expect: () => [
          const CardSettlementLoaded(
            transactions: [tTx1, tTx2],
            selectedIds: {},
            totalAmount: 85000,
          ),
        ],
      );
    });

    group('UpdateCustomAmount', () {
      blocTest<CardSettlementBloc, CardSettlementState>(
        'updates custom amount',
        build: () => bloc,
        seed: () => const CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-1', 'tx-2'},
          totalAmount: 85000,
        ),
        act: (bloc) => bloc.add(const UpdateCustomAmount(50000)),
        expect: () => [
          const CardSettlementLoaded(
            transactions: [tTx1, tTx2],
            selectedIds: {'tx-1', 'tx-2'},
            totalAmount: 85000,
            customAmount: 50000,
          ),
        ],
      );

      blocTest<CardSettlementBloc, CardSettlementState>(
        'clears custom amount with null',
        build: () => bloc,
        seed: () => const CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-1', 'tx-2'},
          totalAmount: 85000,
          customAmount: 50000,
        ),
        act: (bloc) => bloc.add(const UpdateCustomAmount(null)),
        expect: () => [
          const CardSettlementLoaded(
            transactions: [tTx1, tTx2],
            selectedIds: {'tx-1', 'tx-2'},
            totalAmount: 85000,
          ),
        ],
      );
    });

    group('SubmitSettlement', () {
      blocTest<CardSettlementBloc, CardSettlementState>(
        'emits [Submitting, Success] on success',
        build: () {
          when(mockTransferRepo.createCardSettlement(
            sourcePaymentMethodId: 'bank-1',
            destinationPaymentMethodId: 'card-1',
            amount: 85000,
            description: '카드 결제',
            transferDate: '2026-04-14',
            transactionIds: [],
          )).thenAnswer((_) async => Right(Transfer(
                id: 'new',
                coupleId: 'c1',
                author: const TransactionAuthor(id: 'u1', nickname: 'User'),
                sourcePaymentMethod: const PaymentMethodRef(
                    id: 'bank-1', name: 'Bank', type: 'BANK'),
                destinationPaymentMethod: const PaymentMethodRef(
                    id: 'card-1', name: 'Card', type: 'CREDIT'),
                amount: 85000,
                transferDate: '2026-04-14',
                createdAt: DateTime(2026, 4, 14),
              )));
          return bloc;
        },
        seed: () => const CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-1', 'tx-2'},
          totalAmount: 85000,
        ),
        act: (bloc) => bloc.add(const SubmitSettlement(
          sourcePaymentMethodId: 'bank-1',
          destinationPaymentMethodId: 'card-1',
          amount: 85000,
          date: '2026-04-14',
          description: '카드 결제',
        )),
        expect: () => [
          const CardSettlementSubmitting(),
          const CardSettlementSuccess(),
        ],
      );

      blocTest<CardSettlementBloc, CardSettlementState>(
        'emits [Submitting, Error] on failure',
        build: () {
          when(mockTransferRepo.createCardSettlement(
            sourcePaymentMethodId: 'bank-1',
            destinationPaymentMethodId: 'card-1',
            amount: 85000,
            description: '카드 결제',
            transferDate: '2026-04-14',
            transactionIds: [],
          )).thenAnswer((_) async =>
              const Left(ServerFailure('카드 결제를 처리하지 못했습니다')));
          return bloc;
        },
        seed: () => const CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-1', 'tx-2'},
          totalAmount: 85000,
        ),
        act: (bloc) => bloc.add(const SubmitSettlement(
          sourcePaymentMethodId: 'bank-1',
          destinationPaymentMethodId: 'card-1',
          amount: 85000,
          date: '2026-04-14',
          description: '카드 결제',
        )),
        expect: () => [
          const CardSettlementSubmitting(),
          const CardSettlementError('카드 결제를 처리하지 못했습니다'),
        ],
      );
    });

    group('CardSettlementLoaded computed values', () {
      test('selectedAmount sums selected transaction amounts', () {
        const state = CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-1'},
          totalAmount: 85000,
        );
        expect(state.selectedAmount, 5000);
      });

      test('effectiveAmount returns customAmount when set', () {
        const state = CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-1', 'tx-2'},
          totalAmount: 85000,
          customAmount: 50000,
        );
        expect(state.effectiveAmount, 50000);
      });

      test('effectiveAmount returns selectedAmount when no customAmount', () {
        const state = CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-1', 'tx-2'},
          totalAmount: 85000,
        );
        expect(state.effectiveAmount, 85000);
      });

      test('allSelected is true when all transactions selected', () {
        const state = CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-1', 'tx-2'},
          totalAmount: 85000,
        );
        expect(state.allSelected, true);
      });

      test('allSelected is false when not all transactions selected', () {
        const state = CardSettlementLoaded(
          transactions: [tTx1, tTx2],
          selectedIds: {'tx-1'},
          totalAmount: 85000,
        );
        expect(state.allSelected, false);
      });
    });
  });
}
