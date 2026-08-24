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
import 'package:budget_book/features/budget/presentation/widgets/budget_row_actions.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_state.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
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

/// 항목이 그리는 **잉크 상자**(텍스트+아이콘+아바타+진행바 전체를 감싼다).
/// 사용자가 보는 빈 공간은 텍스트가 아니라 이 상자들 사이다.
Rect? _ink(Element item) {
  final rects = <Rect>[];
  for (final f in [
    find.byType(Text),
    find.byType(Icon),
    find.byType(CircleAvatar),
    find.byType(LinearProgressIndicator),
  ]) {
    rects.addAll(find
        .descendant(of: find.byWidget(item.widget), matching: f)
        .evaluate()
        .map(_rect));
  }
  if (rects.isEmpty) return null;
  return rects.reduce((a, b) => a.expandToInclude(b));
}

void _reportInk(String surface, double w, Finder itemFinder) {
  final items = itemFinder.evaluate().toList();
  if (items.length < 2) {
    // ignore: avoid_print
    print('SWEEP|$surface|w=$w|항목 ${items.length}개 — 측정 불가');
    return;
  }
  for (var i = 0; i < items.length - 1 && i < 4; i++) {
    final a = _ink(items[i]);
    final b = _ink(items[i + 1]);
    if (a == null || b == null) continue;
    // ignore: avoid_print
    print('SWEEP|$surface|w=$w|#$i\u2192#${i + 1}'
        '|잉크사이=${(b.top - a.bottom).toStringAsFixed(1)}'
        '|잉크높이=${a.height.toStringAsFixed(1)}');
  }
}

Rect _rect(Element e) {
  final ro = e.renderObject! as RenderBox;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

void main() {
  const cat1 = TransactionCategory(
      id: 'c1',
      name: '식비',
      type: 'EXPENSE',
      icon: 'restaurant',
      color: '#FF5733');
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
    // 실제 예산 탭 하단에는 '자산 현황'(AccountBalanceCard)이 붙는다 — Initial 로 두면
    // 스피너만 나와 그 표면을 재지 못한다.
    when(() => pm.state).thenReturn(PaymentMethodLoaded([
      PaymentMethod(
          id: 'pm1',
          name: '현금',
          type: 'CASH',
          isActive: true,
          isDefault: true,
          displayOrder: 0,
          balance: 300000,
          createdAt: DateTime.parse('2026-01-01T00:00:00Z')),
      PaymentMethod(
          id: 'pm2',
          name: '신한 주거래',
          type: 'BANK',
          isActive: true,
          isDefault: false,
          displayOrder: 1,
          balance: 1250000,
          createdAt: DateTime.parse('2026-01-01T00:00:00Z')),
      PaymentMethod(
          id: 'pm3',
          name: '카카오뱅크',
          type: 'BANK',
          isActive: true,
          isDefault: false,
          displayOrder: 2,
          balance: 99000,
          createdAt: DateTime.parse('2026-01-01T00:00:00Z')),
    ]));
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

  // ⚠ 320 은 제외한다 — 주간 카드가 320dp 에서 **가로 오버플로우**한다(6.2~31px).
  // 대조군 실험(변경 전 여백 xxl 로 되돌림)에서도 같은 오버플로우가 나왔으므로
  // **이번 회차와 무관한 기존 결함**이다. 별건으로 대장에 올린다.
  for (final w in [375.0, 390.0, 430.0, 768.0, 960.0]) {
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
          .descendant(of: find.byWidget(e.widget), matching: find.byType(Text))
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

      // ── 잉크 기준 스윕 (사용자가 보는 빈 공간)
      _reportInk('예산>항목(ListTile)', w, find.byType(ListTile));
      _reportInk('예산>자산현황 항목(EntityTileRow)', w, find.byType(EntityTileRow));
      // 그룹 경계는 **항목↔항목**이 아니다 — 사이에 그룹 헤더(아이콘+라벨)가 있다.
      // 계약 대상은 (앞 그룹 마지막 항목 잉크 하단 → 다음 그룹 **헤더 잉크 상단**).
      {
        final labels = ['현금', '은행 / 체크', '카드'];
        final rows = find.byType(EntityTileRow).evaluate().toList();
        for (final lb in labels) {
          final f = find.text(lb);
          if (f.evaluate().isEmpty) continue;
          final labelRect = _rect(f.evaluate().first);
          // 이 라벨보다 위에 있는 항목 중 가장 아래
          Rect? above;
          for (final r in rows) {
            final ink = _ink(r);
            if (ink == null) continue;
            if (ink.bottom <= labelRect.top &&
                (above == null || ink.bottom > above.bottom)) {
              above = ink;
            }
          }
          if (above == null) continue;
          // ignore: avoid_print
          print('SWEEP|자산현황 항목→그룹헤더|w=$w|"$lb"'
              '|사이=${(labelRect.top - above.bottom).toStringAsFixed(1)}');
        }
      }
      // 같은 표면을 **텍스트 기준**으로도 잰다 — 잉크 기준 초과분이 액션 슬롯(44dp)에서
      // 오는지, 여백에서 오는지 가르는 유일한 방법이다.
      {
        final rows = find.byType(EntityTileRow).evaluate().toList();
        for (var i = 0; i < rows.length - 1 && i < 3; i++) {
          List<Rect> tx(Element e) => find
              .descendant(
                  of: find.byWidget(e.widget), matching: find.byType(Text))
              .evaluate()
              .map(_rect)
              .toList();
          final a = tx(rows[i]);
          final b = tx(rows[i + 1]);
          if (a.isEmpty || b.isEmpty) continue;
          final aB = a.map((r) => r.bottom).reduce((x, y) => x > y ? x : y);
          final bT = b.map((r) => r.top).reduce((x, y) => x < y ? x : y);
          final boxA = _rect(rows[i]);
          // ignore: avoid_print
          print('SWEEP|자산현황 텍스트기준|w=$w|#$i\u2192#${i + 1}'
              '|텍스트사이=${(bT - aB).toStringAsFixed(1)}'
              '|행박스높이=${boxA.height.toStringAsFixed(1)}');
        }
      }

      // 신고②(예산 여백 과다)의 지배 변수: 부제목이 몇 줄로 랩되는가 + 그 폭.
      {
        final tiles0 = find.byType(ListTile).evaluate().toList();
        if (tiles0.isNotEmpty) {
          final t0 = tiles0.first;
          final texts = find
              .descendant(
                  of: find.byWidget(t0.widget), matching: find.byType(Text))
              .evaluate();
          for (final e in texts) {
            final wd = e.widget as Text;
            final rr = _rect(e);
            // ignore: avoid_print
            print('WRAP|예산항목|w=$w|"${wd.data}"'
                '|폭=${rr.width.toStringAsFixed(1)}'
                '|높이=${rr.height.toStringAsFixed(1)}');
          }
        }
      }

      // ── 항목 **높이** 해부 (2026-08-24 추가 — 사용자가 "높이 조정이 안됐다")
      // 사이(gap)와 높이(height)는 지배 변수가 다르다. 무엇이 93dp 를 채우는지 쟨다.
      final tilesA = find.byType(ListTile).evaluate().toList();
      if (tilesA.isNotEmpty) {
        final t0 = tilesA.first;
        final box = _rect(t0);
        Rect? sub(Finder f) {
          final e = find
              .descendant(of: find.byWidget(t0.widget), matching: f)
              .evaluate();
          return e.isEmpty ? null : _rect(e.first);
        }

        final avatar = sub(find.byType(CircleAvatar));
        final title = sub(find.text('식비'));
        final bar = sub(find.byType(LinearProgressIndicator));
        final subtitleTexts = find
            .descendant(
                of: find.byWidget(t0.widget), matching: find.byType(Text))
            .evaluate()
            .map(_rect)
            .toList();
        final lastText = subtitleTexts.isEmpty
            ? null
            : subtitleTexts.reduce((a, b) => a.bottom > b.bottom ? a : b);
        // ignore: avoid_print
        print('ANATOMY|예산항목|w=$w'
            '|박스높이=${box.height.toStringAsFixed(1)}'
            '|아바타=${avatar?.height.toStringAsFixed(1)}'
            '|제목줄=${title?.height.toStringAsFixed(1)}'
            '|진행바=${bar?.height.toStringAsFixed(1)}'
            '|막내텍스트높이=${lastText?.height.toStringAsFixed(1)}');
        if (title != null && bar != null && lastText != null) {
          // ignore: avoid_print
          print('ANATOMY|예산항목 세로분해|w=$w'
              '|상단여백=${(title.top - box.top).toStringAsFixed(1)}'
              '|제목→진행바=${(bar.top - title.bottom).toStringAsFixed(1)}'
              '|진행바→막내텍스트=${(lastText.top - bar.bottom).toStringAsFixed(1)}'
              '|하단여백=${(box.bottom - lastText.bottom).toStringAsFixed(1)}');
        }
      }

      // 부제목이 3줄로 랩되는 이유 = 폭. 랩 원인을 폭으로 특정한다.
      if (tilesA.isNotEmpty) {
        final t0 = tilesA.first;
        Rect? one(Finder f) {
          final e = find
              .descendant(of: find.byWidget(t0.widget), matching: f)
              .evaluate();
          return e.isEmpty ? null : _rect(e.first);
        }

        final box = _rect(t0);
        final texts = find
            .descendant(
                of: find.byWidget(t0.widget), matching: find.byType(Text))
            .evaluate()
            .toList();
        for (final e in texts) {
          final w0 = e.widget as Text;
          final r = _rect(e);
          // ignore: avoid_print
          print('WIDTH|예산항목 텍스트|w=$w'
              '|"${w0.data}"|폭=${r.width.toStringAsFixed(1)}'
              '|높이=${r.height.toStringAsFixed(1)}'
              '|maxLines=${w0.maxLines}');
        }
        final avatar = one(find.byType(CircleAvatar));
        // ignore: avoid_print
        print('WIDTH|예산항목 상자|w=$w|박스폭=${box.width.toStringAsFixed(1)}'
            '|아바타폭=${avatar?.width.toStringAsFixed(1)}');
      }

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
      when(() => bloc.state).thenReturn(
          const BudgetLoaded(budgets: [], summary: null, year: 2026, month: 8));
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
      // 카드 **안쪽** 중첩 목록 = 사용자가 말한 "예산 항목 내".
      // 주간 카드 안의 카테고리 행들(BudgetRowActions → rowBody) 사이를 잉크로 잰다.
      final rows = find.byType(LinearProgressIndicator).evaluate().toList();
      for (var i = 0; i < rows.length - 1 && i < 3; i++) {
        final a = _rect(rows[i]);
        final b = _rect(rows[i + 1]);
        // 진행바 하단 → 다음 행 진행바 상단 사이에는 다음 행의 텍스트가 있다.
        // 그래서 행 단위 잉크 상자를 다시 만든다.
        // ignore: avoid_print
        print('MEASURE|예산>주간 카드내부 진행바간|w=$w|#$i'
            '|진행바사이=${(b.top - a.bottom).toStringAsFixed(1)}');
      }
      _reportInk('예산>주간 카드내부 행', w, find.byType(BudgetRowActions));
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
