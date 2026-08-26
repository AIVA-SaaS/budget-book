// 계측 전용 — **기록 생성 화면(거래 폼)** 의 여백 실측.
//
// 왜 이 파일이 있나 `[측정 2026-08-27]`: 9차 회차는 "도달 가능 화면 세로 리터럴 0" 을
// 완료 기준으로 삼았지만 그 봉인은 **`SizedBox(height:)` 한 경로만** 검사했다.
// 기획서 S3 가 봉인하라고 한 5경로 중 `EdgeInsets.symmetric(vertical:)`(102) ·
// `only(top:/bottom:)`(36) · `all(N)`(129) · `fromLTRB(N)`(22) · `spacing: N`(17) 는
// 그대로 남았다 — 도달 가능 화면 기준 **275건 / 94파일**.
//
// 그리고 회차 이전 커밋(410f791)과 대조하면 기록 생성 화면의 변화는 390dp 에서
// `16 → xxl 15.30`(−0.70) · `12 → xl 10.20`(−1.80) · `8 → lg 8.00`(0.00) ·
// `24 → block 24.00`(0.00) 이었다. 사용자가 "여백이 전혀 적용되지 않은 것 같다"고
// 한 것은 **정확한 관찰**이다. 이 파일은 그 절대값을 못 박아 다음 회차의 대조군으로 쓴다.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';
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
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_form_page.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransactionBloc extends MockBloc<TransactionEvent, TransactionState>
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

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

class _MockTransactionRepository extends Mock
    implements TransactionRepository {}

const widths = <double>[390, 768, 960];

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
    when(() => paymentMethodBloc.state)
        .thenReturn(const PaymentMethodInitial());
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

  /// 프로덕션과 같은 배선: `BbScaleScope` + `AppTheme.responsive`(`app.dart:83~90`).
  /// 이걸 빼면 테마 토큰이 화면 폭을 읽어 실제 화면과 다른 값이 나온다.
  Widget host(double w) => MaterialApp(
        theme: AppTheme.light,
        home: BbScaleScope(
          width: w,
          child: Builder(
            builder: (ctx) => Theme(
              data: AppTheme.responsive(Theme.of(ctx), w),
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<TransactionBloc>.value(value: transactionBloc),
                  BlocProvider<TransferBloc>.value(value: transferBloc),
                  BlocProvider<CategoryBloc>.value(value: categoryBloc),
                  BlocProvider<PaymentMethodBloc>.value(
                      value: paymentMethodBloc),
                  BlocProvider<PocketBloc>.value(value: pocketBloc),
                ],
                child: TransactionFormPage(copyFrom: prefill),
              ),
            ),
          ),
        ),
      );

  for (final w in widths) {
    testWidgets('기록 생성 폼 여백 실측 w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(host(w));
      await t.pumpAndSettle();

      final space = BbSpace.forWidth(w);
      // ignore: avoid_print
      print('FORM|w=$w|토큰: lg=${space.lg.toStringAsFixed(2)} '
          'xl=${space.xl.toStringAsFixed(2)} xxl=${space.xxl.toStringAsFixed(2)} '
          'block=${space.block.toStringAsFixed(2)}');

      // 결제수단·포켓 필드 상자와 그 사이
      final fields = find.byType(ItemSelectorField);
      final n = fields.evaluate().length;
      // ignore: avoid_print
      print('FORM|w=$w|ItemSelectorField 개수=$n');
      for (var i = 0; i < n - 1; i++) {
        final a = t.getRect(fields.at(i));
        final b = t.getRect(fields.at(i + 1));
        // ignore: avoid_print
        print('FORM|w=$w|필드 #$i→#${i + 1}|상자사이=${(b.top - a.bottom).toStringAsFixed(2)}'
            '|상자높이=${a.height.toStringAsFixed(2)}');
      }

      // ★필드 높이를 **누가 소유하나**. 테마 `contentPadding`(lg) 이 닿는지,
      // 프레임워크가 아이콘 최소 터치 타깃(48)으로 고정하는지 갈라야 한다.
      final box = t.getRect(fields.first);
      final icons = find.descendant(of: fields.first, matching: find.byType(Icon));
      for (var i = 0; i < icons.evaluate().length; i++) {
        final ir = t.getRect(icons.at(i));
        // ignore: avoid_print
        print('FORM|w=$w|아이콘 #$i 잉크 ${ir.width.toStringAsFixed(2)}×'
            '${ir.height.toStringAsFixed(2)} @top=${(ir.top - box.top).toStringAsFixed(2)}');
      }
      // prefixIcon 을 감싼 ConstrainedBox 의 최소 높이 = 프레임워크 소유 여부의 지문
      final cbs = find.descendant(
          of: fields.first, matching: find.byType(ConstrainedBox));
      final mins = <String>[];
      for (var i = 0; i < cbs.evaluate().length; i++) {
        final c = t.widget<ConstrainedBox>(cbs.at(i)).constraints;
        if (c.minHeight > 0) mins.add(c.minHeight.toStringAsFixed(1));
      }
      // ignore: avoid_print
      print('FORM|w=$w|필드 상자높이=${box.height.toStringAsFixed(2)} '
          '| 테마 contentPadding 세로=${space.lg.toStringAsFixed(2)} '
          '| 내부 ConstrainedBox minHeight=[${mins.join(",")}]');
      final txt = find.descendant(of: fields.first, matching: find.byType(Text));
      if (txt.evaluate().isNotEmpty) {
        final tr = t.getRect(txt.first);
        // ignore: avoid_print
        print('FORM|w=$w|상자top→첫텍스트top=${(tr.top - box.top).toStringAsFixed(2)} '
            '| 텍스트bottom→상자bottom=${(box.bottom - tr.bottom).toStringAsFixed(2)}');
      }

      // 폼 전체 세로 리듬 — 최상위 Column 의 직속 자식 사이
      final labels = <String>['결제수단 *', '포켓 (선택)'];
      for (final l in labels) {
        final f = find.text(l);
        // ignore: avoid_print
        print('FORM|w=$w|"$l" 존재=${f.evaluate().isNotEmpty}');
      }
    });
  }
}
