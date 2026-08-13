import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_form_page.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_state.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransactionBloc
    extends MockBloc<TransactionEvent, TransactionState>
    implements TransactionBloc {}

class _MockTransferBloc extends MockBloc<TransferEvent, TransferState>
    implements TransferBloc {}

class _MockCategoryBloc extends MockBloc<CategoryEvent, CategoryState>
    implements CategoryBloc {}

class _MockPaymentMethodBloc
    extends MockBloc<PaymentMethodEvent, PaymentMethodState>
    implements PaymentMethodBloc {}

class _MockPocketBloc extends MockBloc<PocketEvent, PocketState>
    implements PocketBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

class _MockTransactionRepository extends Mock
    implements TransactionRepository {}

/// Guard S7 — "저장 & 계속" 은 폼 최상단으로 돌아가야 한다 (사용자 요청 3).
///
/// 저장 버튼은 폼 아래쪽에 있어서, 스크롤을 그대로 두면 다음 항목의 날짜·금액이
/// 화면 밖에 남는다. 지출/수입 폼은 서로 다른 ScrollController 를 써야 하므로
/// **두 탭 각각** 검증한다.
void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  late _MockTransactionBloc transactionBloc;
  late _MockTransferBloc transferBloc;
  late _MockCategoryBloc categoryBloc;
  late _MockPaymentMethodBloc paymentMethodBloc;
  late _MockPocketBloc pocketBloc;
  late _MockAuthBloc authBloc;
  late _MockDashboardBloc dashboardBloc;
  late MonthCubit monthCubit;
  late StreamController<TransactionState> transactionStates;

  setUp(() {
    transactionBloc = _MockTransactionBloc();
    transferBloc = _MockTransferBloc();
    categoryBloc = _MockCategoryBloc();
    paymentMethodBloc = _MockPaymentMethodBloc();
    pocketBloc = _MockPocketBloc();
    authBloc = _MockAuthBloc();
    dashboardBloc = _MockDashboardBloc();
    monthCubit = MonthCubit();
    transactionStates = StreamController<TransactionState>.broadcast();

    whenListen(transactionBloc, transactionStates.stream,
        initialState: const TransactionInitial());
    final repo = _MockTransactionRepository();
    when(() => transactionBloc.transactionRepository).thenReturn(repo);
    when(() => repo.getSuggestions(any(), type: any(named: 'type')))
        .thenAnswer((_) async => const Left(ServerFailure('no suggestions')));
    when(() => transferBloc.state).thenReturn(const TransferInitial());
    when(() => categoryBloc.state).thenReturn(const CategoryInitial());
    when(() => paymentMethodBloc.state).thenReturn(const PaymentMethodInitial());
    when(() => pocketBloc.state).thenReturn(const PocketInitial());
    when(() => authBloc.state).thenReturn(const AuthInitial());
    when(() => dashboardBloc.state).thenReturn(const DashboardInitial());

    getIt.registerSingleton<AuthBloc>(authBloc);
    getIt.registerSingleton<DashboardBloc>(dashboardBloc);
    getIt.registerSingleton<PaymentMethodBloc>(paymentMethodBloc);
    getIt.registerSingleton<MonthCubit>(monthCubit);
  });

  tearDown(() async {
    await transactionStates.close();
    await getIt.reset();
  });

  /// 검증이 통과해야 저장 경로가 실제로 돌아간다(리스너가 `_isSubmitting` 을 본다).
  /// 복사 등록 경로로 카테고리·결제수단·금액을 미리 채운다.
  final prefill = Transaction(
    id: 'txn-seed',
    coupleId: 'couple-1',
    author: const TransactionAuthor(id: 'user-1', nickname: '홍길동'),
    category: const TransactionCategory(
      id: 'cat-1',
      name: '식비',
      type: 'EXPENSE',
      icon: 'restaurant',
      color: '#FF5733',
      groupId: 'group-1',
      groupName: '생활',
    ),
    type: 'EXPENSE',
    amount: 12000,
    description: '점심',
    transactionDate: '2026-08-13',
    paymentMethodId: 'pm-1',
    paymentMethodName: '신한카드',
    createdAt: DateTime(2026, 8, 13),
    updatedAt: DateTime(2026, 8, 13),
  );

  final incomePrefill = Transaction(
    id: 'txn-seed-income',
    coupleId: 'couple-1',
    author: const TransactionAuthor(id: 'user-1', nickname: '홍길동'),
    category: const TransactionCategory(
      id: 'cat-2',
      name: '급여',
      type: 'INCOME',
      icon: 'work',
      color: '#2563EB',
      groupId: 'group-2',
      groupName: '수입',
    ),
    type: 'INCOME',
    amount: 3000000,
    description: '월급',
    transactionDate: '2026-08-13',
    paymentMethodId: 'pm-1',
    paymentMethodName: '신한은행',
    createdAt: DateTime(2026, 8, 13),
    updatedAt: DateTime(2026, 8, 13),
  );

  Widget host({Transaction? seed, String? initialType}) => MaterialApp(
        theme: AppTheme.light,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<TransactionBloc>.value(value: transactionBloc),
            BlocProvider<TransferBloc>.value(value: transferBloc),
            BlocProvider<CategoryBloc>.value(value: categoryBloc),
            BlocProvider<PaymentMethodBloc>.value(value: paymentMethodBloc),
            BlocProvider<PocketBloc>.value(value: pocketBloc),
          ],
          child: TransactionFormPage(
            copyFrom: seed ?? prefill,
            initialType: initialType,
          ),
        ),
      );

  /// The scroll controller of the currently visible form.
  ScrollController visibleFormController(WidgetTester tester) {
    final view = tester.widget<SingleChildScrollView>(
      find
          .descendant(
            of: find.byType(TabBarView),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    return view.controller!;
  }

  Future<void> saveAndContinue(WidgetTester tester) async {
    // "저장 & 계속" 을 누르면 _continueMode 가 켜진다. 실제 저장은 bloc 이 하므로,
    // 저장 성공 상태를 흘려보내 페이지의 성공 리스너를 그대로 태운다.
    await tester.tap(find.text('저장 & 계속'));
    await tester.pump();
    transactionStates.add(const TransactionLoaded(
      transactions: [],
      year: 2026,
      month: 8,
      totalElements: 0,
      hasMore: false,
      currentPage: 0,
    ));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> pumpForm(WidgetTester tester,
      {Transaction? seed, String? initialType}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(seed: seed, initialType: initialType));
    await tester.pumpAndSettle();
  }

  testWidgets('지출 탭: 아래로 스크롤 후 저장 & 계속 → offset 0 + 금액 포커스',
      (tester) async {
    await pumpForm(tester);

    final expense = visibleFormController(tester);
    expense.jumpTo(expense.position.maxScrollExtent);
    await tester.pump();
    expect(expense.offset, greaterThan(0),
        reason: '먼저 아래로 내려가 있어야 검증이 의미가 있다');

    await saveAndContinue(tester);

    expect(expense.offset, 0, reason: '저장 & 계속 후 최상단으로 이동해야 한다');
    expect(tester.binding.focusManager.primaryFocus?.hasFocus, isTrue,
        reason: '금액 입력으로 포커스가 옮겨져야 한다');
  });

  testWidgets('수입 탭: 아래로 스크롤 후 저장 & 계속 → offset 0', (tester) async {
    // 수입 탭으로 바로 진입한다. 탭을 옮기면 카테고리 타입이 달라져 선택이
    // 초기화되므로(폼의 기존 동작) 저장 자체가 막힌다.
    await pumpForm(tester, seed: incomePrefill, initialType: 'INCOME');

    final income = visibleFormController(tester);
    income.jumpTo(income.position.maxScrollExtent);
    await tester.pump();
    expect(income.offset, greaterThan(0));

    await saveAndContinue(tester);

    expect(income.offset, 0);
  });

  testWidgets('지출·수입 폼은 서로 다른 ScrollController 를 쓴다', (tester) async {
    await pumpForm(tester);
    final expense = visibleFormController(tester);

    await tester.tap(find.text('수입'));
    await tester.pumpAndSettle();
    final income = visibleFormController(tester);

    // 하나를 공유하면 두 ScrollView 에 동시에 붙어 런타임 예외가 난다
    // (FocusNode 를 탭별로 분리한 것과 같은 이유).
    expect(identical(expense, income), isFalse);
    expect(tester.takeException(), isNull);
  });
}
