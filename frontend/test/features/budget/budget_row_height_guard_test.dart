// 예산 목록 **행 간 높이 동일성** 가드 + 4축 계측기 (2026-08-26, 7차).
//
// ## 이 파일이 존재하는 이유 `[측정 2026-08-26]`
//
// 6차 라이브 검증에서 사용자 회신: "예산 간의 위 아래 항목 높이도 **자산처럼 일치**
// 시키고 싶었던 건데 잘못 이해한 것 같다."
//
// 6차는 요구를 **높이 축소**로 읽고 잉크높이를 93.0 → 43.0 으로 줄였다. 실제 요구는
// **행 간 동일성**이었다. 두 축은 독립이다 — 줄여도 행마다 다르면 미충족이다.
//
// 원인은 `budget_list_page.dart` 가 `ListTile` 을 쓴 것이다. `ListTile` 은 **프레임워크가
// 높이를 소유**하고, 부제목 Column 안 프로그레스바가 `budgetAmount <= 0` 에서
// `SizedBox.shrink()` 를 돌려줘 **행마다 잉크가 갈렸다**.
//
// ## ★교훈 자체에 구멍이 있었다 (이 가드의 진짜 이유)
//
// 2026-08-24 교훈은 "'여백이 없다/많다' 회신은 **축을 셋으로** 갈라서 잰다:
// 행 사이 · 행 안 위/아래(균형) · 랩(폭)" 이었다. **그 3축에 '행 간 높이 동일성'이 없다.**
// 교훈이 축을 빠뜨렸으니 `row_balance_guard_test` 도 빠뜨렸다(그건 `위 == 아래` 만 본다).
// 그래서 20/20 초록인 채로 이 결함이 배포됐다. 이 파일이 **4번째 축**이다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/widgets/budget_tile.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';

/// 행 높이 차 허용 오차. 0.5 = dp 반올림 한 칸.
const double kHeightTolerance = 0.51;

final _won = NumberFormat('#,###');
final _report = StringBuffer();

String _px(double v) => v.toStringAsFixed(2);

Budget _budget({
  required String id,
  required String name,
  int amount = 300000,
  String visibility = 'SHARED',
}) =>
    Budget(
      id: id,
      coupleId: 'c1',
      category: TransactionCategory(
        id: 'cat-$id',
        name: name,
        type: 'EXPENSE',
        icon: 'restaurant',
        color: '#FF7043',
      ),
      yearMonth: '2026-08',
      amount: amount,
      visibility: visibility,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );

BudgetSummaryItem _summary(Budget b, {required int spent}) => BudgetSummaryItem(
      category: b.category,
      budgetAmount: b.amount,
      spentAmount: spent,
      remainingAmount: b.amount - spent,
      usageRate: b.amount <= 0 ? 0 : spent / b.amount * 100,
    );

/// ★픽스처는 **행마다 값을 달리한다** — 예산액 0 · 개인 · 긴 제목 · 초과까지 섞는다.
/// 이 조합이 종전 결함이 실제로 갈리던 지점이다(0 이면 바가 사라졌다).
List<({Budget budget, BudgetSummaryItem summary, bool private, String label})>
    _fixtures() {
  final rows = <({
    Budget budget,
    BudgetSummaryItem summary,
    bool private,
    String label
  })>[];

  void add(String label, Budget b, int spent, {bool private = false}) {
    rows.add((
      budget: b,
      summary: _summary(b, spent: spent),
      private: private,
      label: label
    ));
  }

  add('일반', _budget(id: '1', name: '식비'), 120000);
  add('예산액 0', _budget(id: '2', name: '교통', amount: 0), 0);
  add('초과', _budget(id: '3', name: '쇼핑', amount: 100000), 180000);
  add('개인', _budget(id: '4', name: '용돈', visibility: 'PRIVATE'), 50000,
      private: true);
  add('긴 제목',
      _budget(id: '5', name: '아주아주아주긴카테고리이름입니다정말로깁니다'), 90000);
  add('경계 80%', _budget(id: '6', name: '문화', amount: 200000), 160000);
  return rows;
}

Widget _wrap(double w, Widget child) => MaterialApp(
      theme: AppTheme.responsive(AppTheme.light, w),
      home: Scaffold(body: BbScaleScope(width: w, child: child)),
    );

Rect _rect(Element e) {
  final ro = e.renderObject! as RenderBox;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

void main() {
  const widths = <double>[390, 430, 768];

  tearDownAll(() {
    // ignore: avoid_print
    print('\n===== 예산 행 4축 계측 리포트 =====\n$_report');
  });

  group('B1. 행 간 높이가 같다 (요구 축)', () {
    for (final w in widths) {
      testWidgets('폭 ${w.toInt()}px — 모든 행의 높이가 서로 같다', (tester) async {
        await tester.binding.setSurfaceSize(Size(w, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final rows = _fixtures();
        await tester.pumpWidget(_wrap(
          w,
          Column(
            children: [
              for (final r in rows)
                BudgetTile(
                  key: ValueKey(r.budget.id),
                  budget: r.budget,
                  summaryItem: r.summary,
                  numberFormat: _won,
                  showPrivateMark: r.private,
                  onTap: () {},
                ),
            ],
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final heights = <String, double>{};
        for (final r in rows) {
          final e = tester.element(find.byKey(ValueKey(r.budget.id)));
          heights[r.label] = _rect(e).height;
        }

        final values = heights.values.toList();
        final spread = values.reduce((a, b) => a > b ? a : b) -
            values.reduce((a, b) => a < b ? a : b);

        _report.writeln('[행 간 높이] w=${w.toInt()} ' +
            heights.entries
                .map((e) => '${e.key}=${_px(e.value)}')
                .join(' · ') +
            ' → 편차 ${_px(spread)}');

        expect(
          spread,
          lessThan(kHeightTolerance),
          reason: '폭 ${w.toInt()}px — 예산 행 높이가 행마다 다르다(편차 ${_px(spread)}px). '
              '$heights\n'
              '사용자 요구는 "예산 간의 위아래 항목 높이도 자산처럼 일치" 다.',
        );
      });
    }
  });

  group('B2. 예산액 0 인 행도 프로그레스 자리를 지킨다 (원인 봉인)', () {
    testWidgets('0 원 행에도 LinearProgressIndicator 가 있다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final zero = _budget(id: 'z', name: '교통', amount: 0);
      await tester.pumpWidget(_wrap(
        390,
        BudgetTile(
          budget: zero,
          summaryItem: _summary(zero, spent: 0),
          numberFormat: _won,
          showPrivateMark: false,
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.byType(LinearProgressIndicator),
        findsOneWidget,
        reason: '예산액이 0 이어도 트랙은 그린다 — 자리를 비우면 그 행만 낮아진다. '
            '이게 원래 결함(SizedBox.shrink())이다.',
      );
    });
  });

  group('B3. 소스 봉인 — ListTile 로 돌아가지 않는다', () {
    final src = File(
            'lib/features/budget/presentation/pages/budget_list_page.dart')
        .readAsStringSync();
    // ★주석을 지우고 본다 — 주석 문구로 만족되는 봉인은 봉인이 아니다(2026-08-24 교훈).
    final code = src
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('예산 페이지에 ListTile 생성자가 없다', () {
      expect(code.contains('ListTile('), isFalse,
          reason: '프레임워크가 높이를 소유하면 여백 토큰으로는 못 고친다');
    });

    test('예산 타일은 EntityTileRow 를 통과한다', () {
      final tileSrc =
          File('lib/features/budget/presentation/widgets/budget_tile.dart')
              .readAsStringSync();
      // ★여기도 주석을 지우고 본다 — 문서에서 옛 코드를 인용하는 것까지 잡으면
      //   봉인이 오탐한다(2026-08-24 교훈의 정확한 적용).
      final tile = tileSrc
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(tile.contains('EntityTileRow('), isTrue);
      expect(tile.contains('SizedBox.shrink()'), isFalse,
          reason: '조건부로 자리를 비우면 행 높이가 갈린다');
    });
  });
}
