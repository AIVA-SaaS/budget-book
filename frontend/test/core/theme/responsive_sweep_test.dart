import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_density.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/bb_tab.dart';

/// 반응형 스윕 — `~/.claude/domains/12-ui-scaling.md` 의 강제 2번.
///
/// 편향 제거 조건을 항목과 동급으로 둔다: **320px 최악 폭**과 **배율 1.3/1.6** 을
/// 반드시 포함한다. 최상 조건(390 × 1.0)만 재면 낙관 편향이다.
void main() {
  const widths = <double>[320, 360, 390, 768, 1024, 1440, 2560];
  const scales = <double>[1.0, 1.3, 1.6];

  group('① 토큰 계약', () {
    test('폰트는 역할별 가독 하한 아래로 내려가지 않는다', () {
      for (final w in widths) {
        final type = BbType.forWidth(w);
        for (final role in BbTextRole.values) {
          final spec = kBbTextSpec[role]!;
          expect(type.size(role), greaterThanOrEqualTo(spec.min),
              reason: 'w=$w $role 이 가독 하한 ${spec.min} 아래로 내려갔다');
          expect(type.size(role), lessThanOrEqualTo(spec.max),
              reason: 'w=$w $role 이 상한 ${spec.max} 을 넘었다');
        }
      }
    });

    test('★역할마다 하한에 닿는 폭이 다르다 — 한 지점에서 전 축이 굳지 않는다', () {
      // calynda 실측 결함의 직접 방지: 비율에 하한을 걸면 320~1024px 전 구간이
      // 통째로 굳는다(반응 0). 가독 px 하한이면 역할마다 해제 폭이 갈린다.
      double unlockWidth(BbTextRole role) {
        for (final w in List.generate(2400, (i) => 200.0 + i)) {
          if (BbType.forWidth(w).size(role) > kBbTextSpec[role]!.min) return w;
        }
        return double.infinity;
      }

      final unlocks = {for (final r in BbTextRole.values) r: unlockWidth(r)};
      expect(unlocks.values.toSet().length, greaterThan(1),
          reason: '모든 역할이 같은 폭에서 풀린다 = 전 축이 한 지점에서 굳는다. '
              '지금 값: $unlocks');

      // 큰 역할은 좁은 화면에서 실제로 줄어야 한다(모바일 개선의 실체).
      final mobile = BbType.forWidth(360);
      final web = BbType.forWidth(1440);
      expect(mobile.display, lessThan(web.display));
      expect(mobile.title, lessThan(web.title));

      // 2026-08-19 정정: 이전 판은 본문을 상수로 뒀으나(min == ref) 사용자가
      // "거래/분석/더보기가 크다"고 지적했다. 자산 탭 실측을 기준점으로 옮겨
      // **본문도 반응**한다. 하한은 여전히 가독 기준 px 다(비율 아님).
      expect(mobile.body, lessThan(web.body));
      expect(mobile.label, lessThan(web.label));
    });

    test('★기준점은 자산 탭이다 — 테마 타이포가 검증된 타일 폰트와 일치한다', () {
      // 2026-08-19 사용자 검증: "자산 내 글자 크기가 딱 적절하다.
      // 거래/분석/더보기 등 모든 곳에 반영되어야 한다."
      //
      // `BbDensity` 의 타일 폰트는 유일하게 폭에 반응하던 체계이고 사용자가 그 값을
      // 승인했다. 따라서 그것이 **기준점**이고, 테마 타이포는 그 값을 지나가야 한다.
      // 이 테스트가 깨지면 둘 중 하나가 표류한 것이다 — 자산 탭 쪽을 정본으로 맞춘다.
      //
      // 하한(모바일)과 상한(웹) 양 끝은 **정확히** 같아야 한다. 그 사이는 `BbDensity`
      // 가 840px 에서 계단으로 뛰는 반면 곡선은 매끄러워 오차를 허용한다.
      // 320/360 은 전 역할이 하한에 걸려 있어 **정확 일치**해야 한다.
      for (final w in [320.0, 360.0]) {
        final d = BbDensity.forWidth(w);
        final th = AppTheme.responsive(AppTheme.light, w).textTheme;
        expect(th.bodyLarge!.fontSize, d.titleFontSize,
            reason: 'w=$w 목록 행 제목이 자산 타일 제목과 달라졌다');
        expect(th.bodyMedium!.fontSize, d.metricFontSize,
            reason: 'w=$w 본문이 자산 타일 지표와 달라졌다');
        expect(th.bodySmall!.fontSize, d.headerLabelFontSize);
        expect(th.labelSmall!.fontSize, d.chipFontSize);
        expect(th.titleLarge!.fontSize, d.headerValueFontSize);
      }
      // 390 부터는 큰 역할이 하한을 벗어나 오르기 시작한다(계단이 아닌 증거) —
      // 자산 계단값보다 **작아지지는 않아야** 한다.
      {
        const w = 390.0;
        final d = BbDensity.forWidth(w);
        final th = AppTheme.responsive(AppTheme.light, w).textTheme;
        expect(th.bodyLarge!.fontSize, greaterThanOrEqualTo(d.titleFontSize));
        expect(th.bodyMedium!.fontSize, greaterThanOrEqualTo(d.metricFontSize));
        expect(th.titleLarge!.fontSize,
            closeTo(d.headerValueFontSize, 0.5));
      }
      for (final w in [960.0, 1440.0]) {
        final d = BbDensity.forWidth(w);
        final th = AppTheme.responsive(AppTheme.light, w).textTheme;
        expect(th.bodyLarge!.fontSize, d.titleFontSize);
        expect(th.bodyMedium!.fontSize, d.metricFontSize);
        expect(th.bodySmall!.fontSize, d.headerLabelFontSize);
        expect(th.labelSmall!.fontSize, d.chipFontSize);
        expect(th.titleLarge!.fontSize, d.headerValueFontSize);
      }
    });

    test('본문도 폭에 반응한다 — 전 구간 상수였던 이전 판의 회귀 방지', () {
      // 이전 판은 `min == ref` 라 320~1440 에서 bodyLarge 가 16.0 붙박이였다.
      // "폭 3배에 반응 0" 은 이 체계가 고치려는 바로 그 결함이다.
      final mobile = AppTheme.responsive(AppTheme.light, 360).textTheme;
      final web = AppTheme.responsive(AppTheme.light, 1440).textTheme;
      expect(mobile.bodyLarge!.fontSize, lessThan(web.bodyLarge!.fontSize!));
      expect(mobile.bodyMedium!.fontSize, lessThan(web.bodyMedium!.fontSize!));
      expect(mobile.bodySmall!.fontSize, lessThan(web.bodySmall!.fontSize!));
      expect(mobile.labelSmall!.fontSize, lessThan(web.labelSmall!.fontSize!));
    });

    test('아이콘은 텍스트와 같은 곡선을 탄다', () {
      expect(BbType.forWidth(360).iconMd, lessThan(BbType.forWidth(1440).iconMd));
      for (final w in widths) {
        final t = BbType.forWidth(w);
        expect(t.iconSm, lessThan(t.iconMd));
        expect(t.iconMd, lessThan(t.iconLg));
      }
    });

    test('여백은 폰트를 따라가되 제곱근으로 완만하다', () {
      final small = BbSpace.forWidth(360);
      final big = BbSpace.forWidth(2560);
      expect(big.md, greaterThan(small.md), reason: '큰 화면에서 여백이 커져야 한다');

      // textScaler 를 분자에 포함한다 → 배율을 올리면 여백도 커진다.
      final plain = BbSpace.forWidth(390);
      final scaled =
          BbSpace.forWidth(390, scaler: const TextScaler.linear(1.6));
      expect(scaled.md, greaterThan(plain.md));
      expect(scaled.md / plain.md, closeTo(1.265, 0.02)); // sqrt(1.6)
    });

    test('hairline 은 결합하지 않는다 — 0.5/1.0 은 토큰 사다리에 없다', () {
      expect(kBbSpaceBase.values, isNot(contains(0.5)));
      expect(kBbSpaceBase.values, isNot(contains(1.0)));
    });

    test('컨테이너 폭 판정이 화면 폭 판정과 다르다', () {
      // ★calynda 가 실측한 결함: 화면은 넓은데 자기 폭은 좁은 자리(우측 패널·그리드
      // 셀)에서 `MediaQuery` 로 판정하면 "데스크톱"으로 그린다.
      // 좁은 컨테이너는 반드시 더 작아야 한다.
      expect(BbType.forWidth(300).body,
          lessThan(BbType.forWidth(1440).body));
      expect(BbType.forWidth(300).title,
          lessThan(BbType.forWidth(1440).title));

      // 타이포는 kBbContentMaxWidth 부근에서 **포화**한다 — 본문 칼럼이 960 으로
      // 묶여 있어 그보다 넓은 화면에서 글자가 더 커질 이유가 없다(의도된 상한).
      expect(BbType.forWidth(kBbContentMaxWidth).body,
          equals(BbType.forWidth(2560).body));
    });
  });

  group('② 크롬 스윕 (분석 탭 구성)', () {
    /// 분석 탭의 실제 크롬 구성을 그대로 세운다 —
    /// AppBar(toolbarHeight 0) + TabBar(bbTab ×2) + 내부 TabBar(bbTab ×4)
    /// + NavigationBar.
    Widget harness(double width) => BbScaleScope(
          width: width,
          child: Builder(
            builder: (context) => Theme(
              data: AppTheme.responsive(AppTheme.light, width),
              child: DefaultTabController(
                length: 2,
                child: Scaffold(
                  appBar: AppBar(
                    toolbarHeight: 0,
                    automaticallyImplyLeading: false,
                    bottom: TabBar(tabs: [
                      bbTab(context,
                          icon: Icons.account_balance_wallet_outlined,
                          label: '예산'),
                      bbTab(context, icon: Icons.bar_chart_outlined, label: '통계'),
                    ]),
                  ),
                  body: DefaultTabController(
                    length: 4,
                    child: Column(
                      children: [
                        TabBar(isScrollable: true, tabs: [
                          bbTab(context,
                              icon: Icons.pie_chart_outline, label: '카테고리별'),
                          bbTab(context, icon: Icons.show_chart, label: '추이'),
                          bbTab(context,
                              icon: Icons.compare_arrows, label: '전년 비교'),
                          bbTab(context,
                              icon: Icons.credit_card, label: '결제수단별'),
                        ]),
                        const Expanded(
                          child: Center(child: Text('데이터', key: Key('content'))),
                        ),
                      ],
                    ),
                  ),
                  bottomNavigationBar: NavigationBar(
                    destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.receipt_long_outlined), label: '거래'),
                      NavigationDestination(
                          icon: Icon(Icons.insights_outlined), label: '분석'),
                      NavigationDestination(
                          icon: Icon(Icons.savings_outlined), label: '자산'),
                      NavigationDestination(
                          icon: Icon(Icons.settings_outlined), label: '더보기'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    for (final w in widths) {
      for (final ts in scales) {
        testWidgets('w=$w 배율=$ts — 오버플로 없음', (tester) async {
          tester.view.physicalSize = Size(w, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(MediaQuery(
            data: MediaQueryData(
              size: Size(w, 780),
              textScaler: TextScaler.linear(ts),
            ),
            child: MaterialApp(home: harness(w)),
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull,
              reason: 'w=$w 배율=$ts 에서 레이아웃 예외가 났다');
        });
      }
    }

    testWidgets('★크롬 예산 — 모바일에서 콘텐츠가 화면의 70% 이상 (래칫)', (tester) async {
      for (final w in [320.0, 360.0, 390.0]) {
        tester.view.physicalSize = Size(w, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(size: Size(w, 780)),
          child: MaterialApp(home: harness(w)),
        ));
        await tester.pumpAndSettle();

        final content = tester.getSize(
          find.ancestor(
            of: find.byKey(const Key('content')),
            matching: find.byType(Expanded),
          ).first,
        );
        final ratio = content.height / 780;
        // 2026-08-18 실측 baseline: 320/360/390 모두 **79.5%**(크롬 160dp).
        // 이관 전(대조군)은 63.6%(크롬 284dp)였고 320~960px 에서 **완전히 동일**했다
        // = 폭에 대한 반응 0. 래칫이므로 회차마다 이 선을 올린다.
        expect(ratio, greaterThanOrEqualTo(0.70),
            reason: 'w=$w 에서 콘텐츠가 ${(ratio * 100).toStringAsFixed(1)}% 뿐이다 — '
                '크롬이 다시 늘었다');
      }
    });

    testWidgets('★배율을 올려도 콘텐츠 폭이 줄지 않는다 (역행 금지)', (tester) async {
      final widthsSeen = <double, double>{};
      for (final ts in scales) {
        tester.view.physicalSize = const Size(390, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 780),
            textScaler: TextScaler.linear(ts),
          ),
          child: MaterialApp(home: harness(390)),
        ));
        await tester.pumpAndSettle();
        widthsSeen[ts] = tester
            .getSize(find.byKey(const Key('content')).first)
            .width;
      }
      expect(widthsSeen[1.3]!, greaterThanOrEqualTo(widthsSeen[1.0]! - 0.01),
          reason: '배율 1.3 에서 텍스트 자리가 되레 줄었다 (calynda 2-4 역행 결함)');
      expect(widthsSeen[1.6]!, greaterThanOrEqualTo(widthsSeen[1.3]! - 0.01));
    });
  });

  group('③ 터치 타깃', () {
    testWidgets('IconButton 은 44dp 하한을 지킨다', (tester) async {
      for (final w in [320.0, 390.0, 1440.0]) {
        await tester.pumpWidget(BbScaleScope(
          width: w,
          child: MaterialApp(
            theme: AppTheme.responsive(AppTheme.light, w),
            home: Scaffold(
              body: Center(
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final size = tester.getSize(find.byType(IconButton));
        expect(size.width, greaterThanOrEqualTo(44.0),
            reason: 'w=$w 에서 탭 타깃이 44dp 아래로 내려갔다 (L4 하한)');
        expect(size.height, greaterThanOrEqualTo(44.0));
      }
    });
  });
}
