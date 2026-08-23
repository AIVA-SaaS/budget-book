// 계측 전용(일회성 대조군) — 분석 > **예산** 탭의 "항목 사이" 실측.
// 예산 항목은 Card 가 아니라 ListTile 이다 → 3차 처방(PR #308)이 실제로 걸렸는지 확인.
// 하네스 mock 배선은 test/features/budget/presentation/pages/budget_list_page_test.dart 와 동일.
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/budget/presentation/pages/budget_list_page.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_state.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_overview.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_bloc.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_event.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_state.dart';

class MockBudgetBloc extends MockBloc<BudgetEvent, BudgetState>
    implements BudgetBloc {}

class MockPaymentMethodBloc
    extends MockBloc<PaymentMethodEvent, PaymentMethodState>
    implements PaymentMethodBloc {}

class MockWeeklyBudgetBloc
    extends MockBloc<WeeklyBudgetEvent, WeeklyBudgetState>
    implements WeeklyBudgetBloc {}

class MockCoupleBloc extends MockBloc<CoupleEvent, CoupleState>
    implements CoupleBloc {}

Rect _rect(Element e) {
  final ro = e.renderObject! as RenderBox;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

void main() {
  const cat1 = TransactionCategory(
      id: 'c1', name: '식비', type: 'EXPENSE', icon: 'restaurant', color: '#FF5733');
  const cat2 = TransactionCategory(
      id: 'c2', name: '교통', type: 'EXPENSE', icon: 'train', color: '#2196F3');
  const cat3 = TransactionCategory(
      id: 'c3', name: '문화', type: 'EXPENSE', icon: 'movie', color: '#9C27B0');

  Budget budget(String id, TransactionCategory c, int amount) => Budget(
        id: id,
        coupleId: 'couple-1',
        category: c,
        yearMonth: '2026-08',
        amount: amount,
        createdAt: DateTime.parse('2026-08-01T12:00:00Z'),
        updatedAt: DateTime.parse('2026-08-01T12:00:00Z'),
      );

  const summary = BudgetSummary(
    yearMonth: '2026-08',
    totalBudget: 900000,
    totalSpent: 520000,
    items: [
      BudgetSummaryItem(
          category: cat1,
          budgetAmount: 400000,
          spentAmount: 250000,
          remainingAmount: 150000,
          usageRate: 62.5),
      BudgetSummaryItem(
          category: cat2,
          budgetAmount: 300000,
          spentAmount: 180000,
          remainingAmount: 120000,
          usageRate: 60.0),
      BudgetSummaryItem(
          category: cat3,
          budgetAmount: 200000,
          spentAmount: 90000,
          remainingAmount: 110000,
          usageRate: 45.0),
    ],
  );

  late MockBudgetBloc bloc;
  late MockWeeklyBudgetBloc weekly;

  setUp(() {
    bloc = MockBudgetBloc();
    final pm = MockPaymentMethodBloc();
    when(() => pm.state).thenReturn(const PaymentMethodInitial());
    final wb = MockWeeklyBudgetBloc();
    when(() => wb.state).thenReturn(const WeeklyBudgetInitial());
    weekly = wb;
    final couple = MockCoupleBloc();
    when(() => couple.state).thenReturn(const CoupleNotLinked());
    for (final unreg in [
      () => getIt.isRegistered<PaymentMethodBloc>()
          ? getIt.unregister<PaymentMethodBloc>()
          : null,
      () => getIt.isRegistered<WeeklyBudgetBloc>()
          ? getIt.unregister<WeeklyBudgetBloc>()
          : null,
      () => getIt.isRegistered<CoupleBloc>()
          ? getIt.unregister<CoupleBloc>()
          : null,
    ]) {
      unreg();
    }
    getIt.registerSingleton<PaymentMethodBloc>(pm);
    getIt.registerSingleton<WeeklyBudgetBloc>(wb);
    getIt.registerSingleton<CoupleBloc>(couple);
  });

  tearDown(() {
    if (getIt.isRegistered<PaymentMethodBloc>()) {
      getIt.unregister<PaymentMethodBloc>();
    }
    if (getIt.isRegistered<WeeklyBudgetBloc>()) {
      getIt.unregister<WeeklyBudgetBloc>();
    }
    if (getIt.isRegistered<CoupleBloc>()) getIt.unregister<CoupleBloc>();
  });

  for (final w in [390.0, 960.0]) {
    testWidgets('분석>예산(월간) w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      when(() => bloc.state).thenReturn(BudgetLoaded(
        budgets: [
          budget('b1', cat1, 400000),
          budget('b2', cat2, 300000),
          budget('b3', cat3, 200000),
        ],
        summary: summary,
        year: 2026,
        month: 8,
      ));
      final monthCubit = MonthCubit()..changeMonth(2026, 8);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.responsive(AppTheme.light, w),
        home: BbScaleScope(
          width: w,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<BudgetBloc>.value(value: bloc),
              BlocProvider<MonthCubit>.value(value: monthCubit),
            ],
            // 분석 탭 내부와 동일한 노출 형태(자체 AppBar·월 네비 없음)
            child: const BudgetListPage(
                showAppBar: false, showMonthNavigator: false),
          ),
        ),
      ));
      await t.pump(const Duration(seconds: 1));

      // 사용자 지표 = 항목 i 의 **마지막 텍스트 하단** → 항목 i+1 의 **첫 텍스트 상단**
      final tileEls = find.byType(ListTile).evaluate().toList();
      List<Rect> textsOf(Element e) => find
          .descendant(
              of: find.byWidget(e.widget), matching: find.byType(Text))
          .evaluate()
          .map(_rect)
          .toList();
      for (var i = 0; i + 1 < tileEls.length && i < 3; i++) {
        final a = textsOf(tileEls[i]);
        final b = textsOf(tileEls[i + 1]);
        if (a.isEmpty || b.isEmpty) continue;
        final aBottom = a.map((r) => r.bottom).reduce((x, y) => x > y ? x : y);
        final bTop = b.map((r) => r.top).reduce((x, y) => x < y ? x : y);
        // ignore: avoid_print
        print('MEASURE|예산>항목사이|w=$w|#$i\u2192#${i + 1}'
            '|텍스트사이=${(bTop - aBottom).toStringAsFixed(1)}');
      }

      // 상단 요약 카드(BudgetSummaryCard) → 첫 항목까지의 사이
      final cards = find.byType(Card).evaluate().toList();
      if (cards.isNotEmpty) {
        final cardRect = _rect(cards.first);
        final firstItem = find.text('식비');
        if (firstItem.evaluate().isNotEmpty) {
          final ir = _rect(firstItem.evaluate().first);
          // ignore: avoid_print
          print('MEASURE|예산>요약카드→첫항목|w=$w'
              '|카드박스하단→텍스트=${(ir.top - cardRect.bottom).toStringAsFixed(1)}'
              '|카드박스높이=${cardRect.height.toStringAsFixed(1)}');
        }
      }
      // ignore: avoid_print
      print('MEASURE|예산>Card개수|w=$w|${cards.length}');

      // ListTile 항목 자체의 상자 높이(밀도 참고)
      final tiles = find.byType(ListTile).evaluate().toList();
      for (var i = 0; i < tiles.length && i < 3; i++) {
        final r = _rect(tiles[i]);
        // ignore: avoid_print
        print('MEASURE|예산>ListTile박스|w=$w|#$i'
            '|높이=${r.height.toStringAsFixed(1)}|top=${r.top.toStringAsFixed(1)}');
      }
    });

    testWidgets('분석>예산(주간) 카드 목록 w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      WeeklyBudgetItem item(String name, int b, int s) => WeeklyBudgetItem(
            budgetId: 'wb-$name',
            categoryId: 'c-$name',
            categoryName: name,
            budgetAmount: b,
            spentAmount: s,
            remainingAmount: b - s,
            usageRate: s / b * 100,
          );
      WeeklyWeek week(int n) => WeeklyWeek(
            weekNumber: n,
            weekStart: '2026-08-0$n',
            weekEnd: '2026-08-0${n + 6}',
            totalBudget: 200000,
            totalSpent: 120000,
            totalRemaining: 80000,
            items: [item('식비', 120000, 80000), item('교통', 80000, 40000)],
          );
      when(() => weekly.state).thenReturn(WeeklyBudgetLoaded(
        overview: WeeklyOverview(
          yearMonth: '2026-08',
          weeks: [week(1), week(2), week(3)],
        ),
        year: 2026,
        month: 8,
      ));
      when(() => bloc.state).thenReturn(const BudgetLoaded(
          budgets: [], summary: null, year: 2026, month: 8));
      final monthCubit = MonthCubit()..changeMonth(2026, 8);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.responsive(AppTheme.light, w),
        home: BbScaleScope(
          width: w,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<BudgetBloc>.value(value: bloc),
              BlocProvider<MonthCubit>.value(value: monthCubit),
            ],
            child: const BudgetListPage(
                showAppBar: false, showMonthNavigator: false),
          ),
        ),
      ));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text('주간'));
      await t.pump(const Duration(seconds: 1));

      final cards = find.byType(Card).evaluate().toList();
      // ignore: avoid_print
      print('MEASURE|예산>주간 Card개수|w=$w|${cards.length}');
      List<Rect> textsOf(Element e) => find
          .descendant(of: find.byWidget(e.widget), matching: find.byType(Text))
          .evaluate()
          .map(_rect)
          .toList();
      for (var i = 0; i + 1 < cards.length && i < 4; i++) {
        final a = textsOf(cards[i]);
        final b = textsOf(cards[i + 1]);
        if (a.isEmpty || b.isEmpty) continue;
        final aB = a.map((r) => r.bottom).reduce((x, y) => x > y ? x : y);
        final bT = b.map((r) => r.top).reduce((x, y) => x < y ? x : y);
        final ra = _rect(cards[i]);
        final rb = _rect(cards[i + 1]);
        // ignore: avoid_print
        print('MEASURE|예산>주간카드사이|w=$w|#$i\u2192#${i + 1}'
            '|텍스트사이=${(bT - aB).toStringAsFixed(1)}'
            '|상자사이=${(rb.top - ra.bottom).toStringAsFixed(1)}');
      }
    });
  }
}
