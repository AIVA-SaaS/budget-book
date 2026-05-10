import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/balance_adjustment_sheet.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';

class MockTransactionBloc extends MockBloc<TransactionEvent, TransactionState>
    implements TransactionBloc {}

class MockPaymentMethodBloc
    extends MockBloc<PaymentMethodEvent, PaymentMethodState>
    implements PaymentMethodBloc {}

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

void main() {
  late MockTransactionBloc mockTransactionBloc;
  late MockPaymentMethodBloc mockPaymentMethodBloc;
  late MockDashboardBloc mockDashboardBloc;

  setUpAll(() {
    registerFallbackValue(const CreateTransaction(
      type: 'EXPENSE',
      amount: 0,
      description: '',
      transactionDate: '2026-01-01',
    ));
    registerFallbackValue(const LoadPaymentMethods());
    registerFallbackValue(const LoadDashboard(year: 2026, month: 1));
  });

  setUp(() {
    mockTransactionBloc = MockTransactionBloc();
    mockPaymentMethodBloc = MockPaymentMethodBloc();
    mockDashboardBloc = MockDashboardBloc();

    when(() => mockTransactionBloc.state).thenReturn(const TransactionInitial());
    when(() => mockPaymentMethodBloc.state).thenReturn(const PaymentMethodInitial());
    when(() => mockDashboardBloc.state).thenReturn(const DashboardInitial());

    if (getIt.isRegistered<TransactionBloc>()) getIt.unregister<TransactionBloc>();
    if (getIt.isRegistered<PaymentMethodBloc>()) getIt.unregister<PaymentMethodBloc>();
    if (getIt.isRegistered<DashboardBloc>()) getIt.unregister<DashboardBloc>();
    if (getIt.isRegistered<MonthCubit>()) getIt.unregister<MonthCubit>();

    getIt.registerSingleton<TransactionBloc>(mockTransactionBloc);
    getIt.registerSingleton<PaymentMethodBloc>(mockPaymentMethodBloc);
    getIt.registerSingleton<DashboardBloc>(mockDashboardBloc);
    // 회차 12 P2 Phase A — sheet 가 MonthCubit 사용 (보던 month 유지).
    getIt.registerLazySingleton<MonthCubit>(() => MonthCubit());
  });

  tearDown(() {
    if (getIt.isRegistered<TransactionBloc>()) getIt.unregister<TransactionBloc>();
    if (getIt.isRegistered<PaymentMethodBloc>()) getIt.unregister<PaymentMethodBloc>();
    if (getIt.isRegistered<DashboardBloc>()) getIt.unregister<DashboardBloc>();
    if (getIt.isRegistered<MonthCubit>()) getIt.unregister<MonthCubit>();
  });

  Widget buildSheet({int currentBalance = 150000}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => BalanceAdjustmentSheet.show(
              context,
              paymentMethodId: 'pm-1',
              paymentMethodName: '신한은행',
              currentBalance: currentBalance,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('BalanceAdjustmentSheet', () {
    testWidgets('shows title, payment method name, and current balance', (tester) async {
      await tester.pumpWidget(buildSheet());
      await openSheet(tester);

      expect(find.text('잔액 수정'), findsOneWidget);
      expect(find.text('신한은행'), findsOneWidget);
      expect(find.text('150,000원'), findsOneWidget);
      expect(find.text('실제 잔액'), findsOneWidget);
    });

    testWidgets('submit button is disabled when no input', (tester) async {
      await tester.pumpWidget(buildSheet());
      await openSheet(tester);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('shows expense preview when actual < current', (tester) async {
      await tester.pumpWidget(buildSheet(currentBalance: 150000));
      await openSheet(tester);

      // Enter 145,000
      await tester.enterText(find.byType(TextFormField).first, '145000');
      await tester.pump();

      expect(find.textContaining('지출 거래 생성'), findsOneWidget);
    });

    testWidgets('shows income preview when actual > current', (tester) async {
      await tester.pumpWidget(buildSheet(currentBalance: 150000));
      await openSheet(tester);

      // Enter 155,000
      await tester.enterText(find.byType(TextFormField).first, '155000');
      await tester.pump();

      expect(find.textContaining('수입 거래 생성'), findsOneWidget);
    });

    testWidgets('shows match message when actual == current', (tester) async {
      await tester.pumpWidget(buildSheet(currentBalance: 150000));
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField).first, '150000');
      await tester.pump();

      expect(find.text('현재 잔액과 동일합니다'), findsOneWidget);

      // Button should be disabled
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    // 회차 1 (2026-05-10) — Z2 race fix.
    // BlocListener<TransactionBloc> 가 TransactionLoaded 수신 후에만 다른 BLoC
    // reload 를 발사한다. 테스트에서 StreamController 를 통해 _submit 호출
    // **후** 에 emit 하여 실제 production race window 를 시뮬레이션.
    TransactionLoaded loadedState() => const TransactionLoaded(
          transactions: [],
          year: 2026,
          month: 1,
          totalElements: 0,
          hasMore: false,
        );

    /// helper — controlled stream + initial state.
    /// emitLoaded() 를 호출하면 Loaded 가 stream 에 push 된다.
    ({Stream<TransactionState> stream, void Function() emitLoaded}) setupTxStream() {
      // ignore: close_sinks — managed in test teardown
      final controller = StreamController<TransactionState>.broadcast();
      addTearDown(controller.close);
      return (
        stream: controller.stream,
        emitLoaded: () => controller.add(loadedState()),
      );
    }

    testWidgets('submits EXPENSE transaction when actual < current', (tester) async {
      final tx = setupTxStream();
      whenListen(mockTransactionBloc, tx.stream,
          initialState: const TransactionInitial());
      await tester.pumpWidget(buildSheet(currentBalance: 150000));
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField).first, '145000');
      await tester.pump();

      // Tap submit
      await tester.tap(find.text('조정'));
      await tester.pump();
      // BE 가 commit 한 후 emit (race 시 BE 응답 도착 시점).
      tx.emitLoaded();
      await tester.pumpAndSettle();

      // Verify CreateTransaction was dispatched
      final captured = verify(() => mockTransactionBloc.add(captureAny())).captured;
      expect(captured, isNotEmpty);
      final event = captured.first as CreateTransaction;
      expect(event.type, 'EXPENSE');
      expect(event.amount, 5000);
      expect(event.description, '잔액 수정');
      expect(event.paymentMethodId, 'pm-1');

      // Verify blocs are refreshed — only AFTER TransactionLoaded received.
      verify(() => mockPaymentMethodBloc.add(const LoadPaymentMethods())).called(1);
      verify(() => mockDashboardBloc.add(any(that: isA<LoadDashboard>()))).called(1);
    });

    testWidgets('submits INCOME transaction when actual > current', (tester) async {
      final tx = setupTxStream();
      whenListen(mockTransactionBloc, tx.stream,
          initialState: const TransactionInitial());
      await tester.pumpWidget(buildSheet(currentBalance: 100000));
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField).first, '105000');
      await tester.pump();

      await tester.tap(find.text('조정'));
      await tester.pump();
      tx.emitLoaded();
      await tester.pumpAndSettle();

      final captured = verify(() => mockTransactionBloc.add(captureAny())).captured;
      expect(captured, isNotEmpty);
      final event = captured.first as CreateTransaction;
      expect(event.type, 'INCOME');
      expect(event.amount, 5000);
    });

    testWidgets('memo (when entered) flows into CreateTransaction.memo',
        (tester) async {
      final tx = setupTxStream();
      whenListen(mockTransactionBloc, tx.stream,
          initialState: const TransactionInitial());
      await tester.pumpWidget(buildSheet(currentBalance: 100000));
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField).first, '120000');
      await tester.pump();

      // memo field 는 두 번째 TextFormField (calculator amount field 다음).
      await tester.enterText(find.byType(TextFormField).at(1), '월급 일부 누락');
      await tester.pump();

      await tester.tap(find.text('조정'));
      await tester.pump();
      tx.emitLoaded();
      await tester.pumpAndSettle();

      final captured = verify(() => mockTransactionBloc.add(captureAny())).captured;
      final event = captured.first as CreateTransaction;
      expect(event.memo, '월급 일부 누락');
    });

    testWidgets('memo (empty) maps to null memo in CreateTransaction',
        (tester) async {
      final tx = setupTxStream();
      whenListen(mockTransactionBloc, tx.stream,
          initialState: const TransactionInitial());
      await tester.pumpWidget(buildSheet(currentBalance: 100000));
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField).first, '110000');
      await tester.pump();
      // memo 입력 안 함

      await tester.tap(find.text('조정'));
      await tester.pump();
      tx.emitLoaded();
      await tester.pumpAndSettle();

      final captured = verify(() => mockTransactionBloc.add(captureAny())).captured;
      final event = captured.first as CreateTransaction;
      expect(event.memo, isNull);
    });

    // 회차 1 (2026-05-10) — Z2 race fix 회귀 방지.
    // CreateTransaction dispatch 직후 TransactionLoaded 가 emit 되기 전에는
    // PaymentMethod/Dashboard reload 가 fire 되지 않아야 한다 (race 원인).
    testWidgets('Z2 race: PaymentMethod/Dashboard reload only AFTER TransactionLoaded',
        (tester) async {
      // 의도적으로 Loaded 미emit — BLoC 가 처리 중인 시점을 시뮬레이션.
      whenListen(
        mockTransactionBloc,
        const Stream<TransactionState>.empty(),
        initialState: const TransactionInitial(),
      );
      await tester.pumpWidget(buildSheet(currentBalance: 100000));
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField).first, '120000');
      await tester.pump();

      await tester.tap(find.text('조정'));
      await tester.pump(const Duration(milliseconds: 200));

      // CreateTransaction 은 dispatch 되어야 한다.
      verify(() => mockTransactionBloc.add(any(that: isA<CreateTransaction>())))
          .called(1);
      // 하지만 PaymentMethod/Dashboard reload 는 아직 NOT 발생.
      verifyNever(() => mockPaymentMethodBloc.add(const LoadPaymentMethods()));
      verifyNever(
          () => mockDashboardBloc.add(any(that: isA<LoadDashboard>())));
    });
  });
}
