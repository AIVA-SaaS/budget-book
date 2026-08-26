// 예산 항목이 **상위 총 예산 카드에 묶인다** 가드 (2026-08-26, 8차).
//
// ## 이 파일이 존재하는 이유
//
// 7차 라이브 회신: "높이 조정이 잘 됐다. 근데 **상위 총 예산에 각 예산항목이 묶이는
// 개념**이기 때문에 **펼치기/숨기기 가능한 구조**여야하고 UI도 그렇게 엮여야할 것 같은데
// 지금은 **별도로 떨어진 것 처럼** 되었다."
//
// `[측정: 코드]` 종전 구조는 `Column[MonthNavigator, BudgetSummaryCard,
// Expanded(ListView(항목들))]` — 카드와 항목이 **형제**였고 계층을 표현하는 장치가
// 하나도 없었다. 게다가 7차 이관으로 항목 인셋이 16 → 10.2 로 줄어 카드보다 **5.8px
// 더 바깥으로** 나가 분리감이 커졌다.
//
// 승인된 형태(사용자 선택) = **한 카드 안에 합친다**.
//
// ★7차 요구(행 간 높이 동일성)는 이 파일의 G4 가 무회귀로 지킨다 — 축이 다르다.
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';
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

/// 허용 오차 — dp 반올림 한 칸.
const double kTol = 0.51;

final _report = StringBuffer();
String _px(double v) => v.toStringAsFixed(2);

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

  Budget budget(String id, TransactionCategory? c, int amount) => Budget(
        id: id,
        coupleId: 'couple-1',
        category: c,
        yearMonth: '2026-08',
        amount: amount,
        createdAt: DateTime.parse('2026-08-01T12:00:00Z'),
        updatedAt: DateTime.parse('2026-08-01T12:00:00Z'),
      );

  // ★예산액 0 인 행을 반드시 포함한다 — 7차 결함이 갈리던 분기다.
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
          budgetAmount: 0,
          spentAmount: 0,
          remainingAmount: 0,
          usageRate: 0),
      BudgetSummaryItem(
          category: cat3,
          budgetAmount: 200000,
          spentAmount: 270000,
          remainingAmount: -70000,
          usageRate: 135.0),
    ],
  );

  late MockBudgetBloc bloc;

  setUp(() {
    bloc = MockBudgetBloc();
    final pm = MockPaymentMethodBloc();
    when(() => pm.state).thenReturn(const PaymentMethodLoaded([]));
    final wb = MockWeeklyBudgetBloc();
    when(() => wb.state).thenReturn(const WeeklyBudgetInitial());
    final couple = MockCoupleBloc();
    when(() => couple.state).thenReturn(const CoupleNotLinked());
    if (getIt.isRegistered<PaymentMethodBloc>()) {
      getIt.unregister<PaymentMethodBloc>();
    }
    if (getIt.isRegistered<WeeklyBudgetBloc>()) {
      getIt.unregister<WeeklyBudgetBloc>();
    }
    if (getIt.isRegistered<CoupleBloc>()) getIt.unregister<CoupleBloc>();
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

  tearDownAll(() {
    // ignore: avoid_print
    print('\n===== 예산 그룹 카드 계측 리포트 =====\n$_report');
  });

  Future<void> pump(WidgetTester t, double w) async {
    await t.binding.setSurfaceSize(Size(w, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    when(() => bloc.state).thenReturn(BudgetLoaded(
      budgets: [
        budget('b1', cat1, 400000),
        budget('b2', cat2, 0),
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
          child: const BudgetListPage(
              showAppBar: false, showMonthNavigator: false),
        ),
      ),
    ));
    await t.pump(const Duration(seconds: 1));
  }

  /// 상위 총 예산 카드 — 헤더 텍스트의 최근접 조상 Card.
  Finder totalCard() => find
      .ancestor(of: find.text('이번 달 예산'), matching: find.byType(Card))
      .first;

  group('G1. 항목이 상위 총 예산 카드의 자손이다', () {
    for (final w in [390.0, 430.0, 768.0]) {
      testWidgets('w=$w — 예산 항목 3개가 모두 카드 안에 있다', (t) async {
        await pump(t, w);
        final inside = find
            .descendant(of: totalCard(), matching: find.byType(EntityTileRow))
            .evaluate()
            .length;
        _report.writeln('[G1] w=$w 카드 안 항목 $inside개');
        expect(inside, 3,
            reason: '항목이 카드 밖 형제로 남아 있으면 "별도로 떨어진 것"으로 읽힌다. '
                '관계는 여백이 아니라 컨테이너가 소유해야 한다');
      });
    }
  });

  group('G2. 펼치기/숨기기', () {
    testWidgets('헤더 토글로 항목이 접히고 다시 펼쳐진다', (t) async {
      await pump(t, 390);
      expect(find.byType(EntityTileRow), findsNWidgets(3),
          reason: '기본은 펼침이다');

      final toggle = find.descendant(
          of: totalCard(), matching: find.byIcon(Icons.expand_less));
      expect(toggle, findsOneWidget,
          reason: '펼침 상태에서는 접기 어포던스(▴)가 보여야 한다 — '
              '2026-07-27 처럼 chevron 이 다른 위젯에 덮이면 사용자가 못 찾는다');

      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(find.byType(EntityTileRow), findsNothing, reason: '접으면 항목이 사라진다');

      final reopen = find.descendant(
          of: totalCard(), matching: find.byIcon(Icons.expand_more));
      expect(reopen, findsOneWidget, reason: '접힌 상태에서는 펼치기 어포던스(▾)');
      await t.tap(reopen);
      await t.pumpAndSettle();
      expect(find.byType(EntityTileRow), findsNWidgets(3),
          reason: '다시 펼치면 항목이 돌아온다');
    });
  });

  group('G3. 항목 선행 경계가 헤더 텍스트와 같은 줄에 정렬된다', () {
    // ★축 정의: **제목**을 헤더에 맞출 수는 없다 — 항목에는 아바타가 있어 제목은
    //   항상 아바타 뒤에서 시작한다(대조군 실측 48.57 vs 헤더 32.00). 사용자가 보는
    //   "줄"은 행이 시작하는 **칠해진 선행 상자**(아바타 원)의 좌측이다.
    //   ⚠ 아이콘 잉크로 재면 원 안쪽 여백(7px)만큼 밀려 허용오차를 늘려야 하는데,
    //     그건 축을 눈속임하는 것이다 — 상자로 재면 오차 없이 맞는다.
    for (final w in [390.0, 430.0, 768.0]) {
      testWidgets('w=$w — 항목 아바타 상자 좌측 == 헤더 제목 좌측', (t) async {
        await pump(t, w);
        final headerLeft = _rect(t.element(find.text('이번 달 예산'))).left;

        final row = find.byType(EntityTileRow).evaluate().first;
        final boxes = find
            .descendant(
                of: find.byWidget(row.widget),
                matching: find.byType(Container))
            .evaluate()
            .where((e) {
              final c = e.widget as Container;
              return c.color != null || c.decoration != null;
            })
            .map((e) => _rect(e).left)
            .toList();
        expect(boxes, isNotEmpty, reason: '칠해진 선행 상자(아바타)를 못 찾았다');
        final leadingLeft = boxes.reduce((a, b) => a < b ? a : b);

        _report.writeln('[G3] w=$w 헤더=${_px(headerLeft)} '
            '항목아바타=${_px(leadingLeft)} 차=${_px(leadingLeft - headerLeft)}');
        expect((leadingLeft - headerLeft).abs(), lessThan(kTol),
            reason: '항목이 헤더와 다른 줄에서 시작하면 계층이 흐려진다');
      });
    }
  });

  group('G4. 무회귀 — 카드 안에서도 행 간 높이가 같다 (7차 계약)', () {
    for (final w in [390.0, 430.0]) {
      testWidgets('w=$w — 행 높이 편차 0', (t) async {
        await pump(t, w);
        final rows = find.byType(EntityTileRow).evaluate().toList();
        expect(rows.length, 3);
        final hs = rows.map((e) => _rect(e).height).toList();
        final spread = hs.reduce((a, b) => a > b ? a : b) -
            hs.reduce((a, b) => a < b ? a : b);
        _report.writeln('[G4] w=$w 높이=${hs.map(_px).join(" · ")} '
            '편차=${_px(spread)}');
        expect(spread, lessThan(kTol),
            reason: '7차 요구(행 간 높이 동일성)는 유지해야 한다 — 사용자가 '
                '"높이는 지금 변경된거 유지해줘"라고 명시했다');
      });
    }
  });

  group('G5. 소스 봉인 — 카드가 리스트 밖 형제로 돌아가지 않는다', () {
    final code = File(
            'lib/features/budget/presentation/pages/budget_list_page.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('_buildLoaded 가 BudgetSummaryCard 를 Expanded 밖 형제로 두지 않는다', () {
      // 종전 결함 형태: Column[..., BudgetSummaryCard(...), Expanded(child: 리스트)]
      final sibling = RegExp(
              r'BudgetSummaryCard\([^)]*\),\s*Expanded\(', multiLine: true)
          .hasMatch(code.replaceAll(RegExp(r'\s+'), ' '));
      expect(sibling, isFalse,
          reason: '카드와 리스트가 형제로 돌아가면 관계가 다시 끊긴다');
    });

    test('항목 인셋은 리터럴이 아니라 토큰 산술이다', () {
      expect(code.contains('bbSpace.xl'), isTrue,
          reason: '정렬 인셋을 16 같은 리터럴로 박으면 토큰이 바뀔 때 어긋난다 '
              '— 타일 자체 인셋(space.xl)을 빼는 산술이어야 한다');
    });
  });
}
