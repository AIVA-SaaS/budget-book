import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:dartz/dartz.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/card_settlement/domain/entities/settlement_transaction.dart';
import 'package:budget_book/features/card_settlement/domain/repositories/card_settlement_repository.dart';
import 'package:budget_book/features/card_settlement/presentation/bloc/card_settlement_bloc.dart';
import 'package:budget_book/features/card_settlement/presentation/bloc/card_settlement_state.dart';
import 'package:budget_book/features/card_settlement/presentation/pages/card_settlement_page.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transfer/domain/repositories/transfer_repository.dart';

class MockPaymentMethodBloc
    extends MockBloc<PaymentMethodEvent, PaymentMethodState>
    implements PaymentMethodBloc {}

// 정산 후보 조회는 datasource 레벨에서 스텁한다 (API 호출 경계 준수).
class FakeCardSettlementRepository implements CardSettlementRepository {
  SettlementTransactionsResponse response;
  String? capturedSettlementTransferId;

  FakeCardSettlementRepository(this.response);

  @override
  Future<Either<Failure, SettlementTransactionsResponse>>
      getSettlementTransactions({
    required String paymentMethodId,
    required int year,
    required int month,
    String? settlementTransferId,
  }) async {
    capturedSettlementTransferId = settlementTransferId;
    return Right(response);
  }
}

class FakeTransferRepository implements TransferRepository {
  bool updateCalled = false;
  String? capturedTransferId;
  List<String>? capturedTransactionIds;

  @override
  Future<Either<Failure, Transfer>> updateCardSettlement({
    required String transferId,
    required String sourcePaymentMethodId,
    required String destinationPaymentMethodId,
    required int amount,
    required String transferDate,
    String? description,
    required List<String> transactionIds,
  }) async {
    updateCalled = true;
    capturedTransferId = transferId;
    capturedTransactionIds = transactionIds;
    // 성공 listener 가 getIt 의 다른 BLoC 을 건드리지 않도록 의도적으로 실패 반환.
    return const Left(ServerFailure('테스트 종료'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  late MockPaymentMethodBloc mockPaymentMethodBloc;
  late FakeCardSettlementRepository fakeSettlementRepo;
  late FakeTransferRepository fakeTransferRepo;
  late CardSettlementBloc settlementBloc;

  final tCard = PaymentMethod(
    id: 'card-1',
    name: '신한카드',
    type: 'CREDIT',
    isActive: true,
    isDefault: false,
    displayOrder: 1,
    linkedBankId: 'bank-1',
    createdAt: DateTime(2026),
  );

  final tBank = PaymentMethod(
    id: 'bank-1',
    name: '국민은행',
    type: 'BANK',
    isActive: true,
    isDefault: false,
    displayOrder: 1,
    createdAt: DateTime(2026),
  );

  // tx-1: 편집 중 정산(st-1)에 이미 묶임. tx-2: 미결제.
  const tLinkedTx = SettlementTransaction(
    id: 'tx-1',
    transactionDate: '2026-03-15',
    description: '편의점',
    amount: 5000,
    settlementTransferId: 'st-1',
  );
  const tUnpaidTx = SettlementTransaction(
    id: 'tx-2',
    transactionDate: '2026-03-20',
    description: '주유',
    amount: 80000,
  );

  setUpAll(() async {
    await initializeDateFormatting('ko');
  });

  setUp(() {
    mockPaymentMethodBloc = MockPaymentMethodBloc();
    when(() => mockPaymentMethodBloc.state)
        .thenReturn(PaymentMethodLoaded([tCard, tBank]));

    fakeSettlementRepo = FakeCardSettlementRepository(
      const SettlementTransactionsResponse(
        totalAmount: 85000,
        transactionCount: 2,
        transactions: [tLinkedTx, tUnpaidTx],
      ),
    );
    fakeTransferRepo = FakeTransferRepository();
    settlementBloc = CardSettlementBloc(
      cardSettlementRepository: fakeSettlementRepo,
      transferRepository: fakeTransferRepo,
    );

    final getIt = GetIt.instance;
    if (getIt.isRegistered<PaymentMethodBloc>()) {
      getIt.unregister<PaymentMethodBloc>();
    }
    getIt.registerSingleton<PaymentMethodBloc>(mockPaymentMethodBloc);
  });

  tearDown(() {
    settlementBloc.close();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PaymentMethodBloc>()) {
      getIt.unregister<PaymentMethodBloc>();
    }
  });

  Widget buildEditWidget() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<CardSettlementBloc>.value(value: settlementBloc),
          BlocProvider<PaymentMethodBloc>.value(value: mockPaymentMethodBloc),
        ],
        child: const CardSettlementPage(
          settlementTransferId: 'st-1',
          initialCardId: 'card-1',
          initialBankId: 'bank-1',
          initialAmount: 5000,
          initialDate: '2026-04-14',
          initialYear: 2026,
          initialMonth: 3,
        ),
      ),
    );
  }

  // initState 에서 dispatch 된 LoadSettlement 의 결과를 위젯 트리에 반영한다.
  // 실제 비동기 존에서 bloc 이 Loaded 를 emit 할 때까지 대기 후 rebuild.
  Future<void> settleLoad(WidgetTester tester) async {
    await tester.pump();
    if (settlementBloc.state is! CardSettlementLoaded) {
      await tester.runAsync(() => settlementBloc.stream
          .firstWhere((s) => s is CardSettlementLoaded)
          .timeout(const Duration(seconds: 2)));
    }
    await tester.pump();
  }

  group('CardSettlementPage edit mode', () {
    testWidgets('shows edit title and passes settlementTransferId on load',
        (tester) async {
      await tester.pumpWidget(buildEditWidget());
      await settleLoad(tester);

      expect(find.text('카드 정산 수정'), findsOneWidget);
      expect(fakeSettlementRepo.capturedSettlementTransferId, 'st-1');
    });

    testWidgets('pre-selects only the transaction linked to the settlement',
        (tester) async {
      await tester.pumpWidget(buildEditWidget());
      await settleLoad(tester);

      final loaded = settlementBloc.state;
      expect(loaded, isA<CardSettlementLoaded>());
      expect((loaded as CardSettlementLoaded).selectedIds, {'tx-1'});
    });

    testWidgets('save button dispatches UpdateSettlement with linked ids',
        (tester) async {
      await tester.pumpWidget(buildEditWidget());
      await settleLoad(tester);

      // 저장 버튼(수정): 편집 모드는 save 아이콘. ListView 하단이라 끌어올려 빌드 유도.
      final saveButton = find.widgetWithIcon(FilledButton, Icons.save);
      for (var i = 0; i < 6 && saveButton.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // 확인 다이얼로그의 '수정' 버튼.
      final confirmButton = find.widgetWithText(FilledButton, '수정');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(fakeTransferRepo.updateCalled, isTrue);
      expect(fakeTransferRepo.capturedTransferId, 'st-1');
      expect(fakeTransferRepo.capturedTransactionIds, ['tx-1']);
    });
  });
}
