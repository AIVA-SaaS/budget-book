import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/bb_tab.dart';

/// 반응형 스윕 — `~/.claude/domains/12-ui-scaling.md` 의 강제 2번.
///
/// 편향 제거 조건을 항목과 동급으로 둔다: **320px 최악 폭**과 **배율 1.3/1.6** 을
/// 반드시 포함한다. 최상 조건(390 × 1.0)만 재면 낙관 편향이다.
/// ★사용자가 승인한 **자산 탭** 실측값(2026-08-19 · 2026-08-20).
///
/// 이 표는 **테스트가 소유한다** — 코드(`kBbSpaceSpec` 등)에서 읽어 오면 순환 검증이 되고
/// "곡선을 바꿨더니 기준점도 같이 움직였다"를 잡을 수 없다. `BbDensity`(3단 계단)가
/// 정본이던 시절의 값이며, 그 클래스는 2026-08-20 에 삭제됐다(경쟁 경로 0개).
///
/// `(compact = <400dp, wide = >=840dp)`
const anchors = <String, ({double compact, double wide})>{
  'tilePaddingH': (compact: 10, wide: 16), // → BbSpaceToken.xl
  // ★2026-08-21 사용자 승인 — 타일 세로 padding 을 한 단계 촘촘하게(`lg`→`md`).
  // 인접 항목 간격 16.0 → 12.8dp @390 · 24 → 20dp @960. 토큰 곡선(`lg` 8/12)은 그대로이고
  // **타일이 쓰는 토큰이 바뀌었다** — 그래서 `lg` 앵커는 아래 `radiusMd` 로 이름만 옮겼다
  // (카드·입력 반지름 · dividerTheme.space · tabBar labelPadding 이 여전히 쓴다).
  'tilePaddingV': (compact: 6, wide: 10), //  → BbSpaceToken.md
  'radiusMd': (compact: 8, wide: 12), //      → BbSpaceToken.lg
  'gap': (compact: 6, wide: 10), //           → BbSpaceToken.md
  'chipPaddingH': (compact: 5, wide: 8), //   → BbSpaceToken.sm
  'avatar': (compact: 32, wide: 40),
  'avatarIcon': (compact: 18, wide: 22),
  'actionIcon': (compact: 20, wide: 24),
  'titleFontSize': (compact: 14, wide: 16), // → bodyLarge / BbType.section
  'metricFontSize': (compact: 13, wide: 15), //→ bodyMedium / BbType.body
  'chipFontSize': (compact: 10, wide: 12), //  → labelSmall / BbType.caption
  'headerLabel': (compact: 11, wide: 12), //   → bodySmall / BbType.label
  'headerValue': (compact: 15, wide: 19), //   → titleLarge / BbType.title
};

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

    test('★기준점은 자산 탭이다 — 테마 타이포가 승인값을 지나간다', () {
      // 2026-08-19 사용자 검증: "자산 내 글자 크기가 딱 적절하다.
      // 거래/분석/더보기 등 모든 곳에 반영되어야 한다."
      //
      // 앵커는 이 파일이 소유한다(위 [anchors]). 하한(모바일)과 상한(웹) 양 끝은
      // **정확히** 같아야 하고, 그 사이는 곡선이므로 오차를 허용한다.
      for (final w in [320.0, 360.0]) {
        final th = AppTheme.responsive(AppTheme.light, w).textTheme;
        expect(th.bodyLarge!.fontSize, anchors['titleFontSize']!.compact,
            reason: 'w=$w 목록 행 제목이 자산 타일 제목과 달라졌다');
        expect(th.bodyMedium!.fontSize, anchors['metricFontSize']!.compact,
            reason: 'w=$w 본문이 자산 타일 지표와 달라졌다');
        expect(th.bodySmall!.fontSize, anchors['headerLabel']!.compact);
        expect(th.labelSmall!.fontSize, anchors['chipFontSize']!.compact);
        expect(th.titleLarge!.fontSize, anchors['headerValue']!.compact);
      }
      // 390 부터는 큰 역할이 하한을 벗어나 오르기 시작한다(계단이 아닌 증거).
      {
        final th = AppTheme.responsive(AppTheme.light, 390).textTheme;
        expect(th.bodyLarge!.fontSize,
            greaterThanOrEqualTo(anchors['titleFontSize']!.compact));
        expect(th.bodyMedium!.fontSize,
            greaterThanOrEqualTo(anchors['metricFontSize']!.compact));
        expect(th.titleLarge!.fontSize,
            closeTo(anchors['headerValue']!.compact, 0.5));
      }
      for (final w in [960.0, 1440.0]) {
        final th = AppTheme.responsive(AppTheme.light, w).textTheme;
        expect(th.bodyLarge!.fontSize, anchors['titleFontSize']!.wide);
        expect(th.bodyMedium!.fontSize, anchors['metricFontSize']!.wide);
        expect(th.bodySmall!.fontSize, anchors['headerLabel']!.wide);
        expect(th.labelSmall!.fontSize, anchors['chipFontSize']!.wide);
        expect(th.titleLarge!.fontSize, anchors['headerValue']!.wide);
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
      expect(
          BbType.forWidth(360).iconMd, lessThan(BbType.forWidth(1440).iconMd));
      for (final w in widths) {
        final t = BbType.forWidth(w);
        expect(t.iconSm, lessThan(t.iconMd));
        expect(t.iconMd, lessThan(t.iconLg));
      }
    });

    test('★여백은 폭에 반응한다 — 7% 상수였던 이전 판의 회귀 방지', () {
      // ⚠ 이 테스트는 2026-08-20 에 **의도적으로 갱신**됐다. 이전 판은
      // "여백은 폰트를 따라가되 제곱근" 이었고, 그 결합(순 폭지수 0.125)이
      // 폰트 clamp(13~15)에 묶여 계수 범위가 0.964~1.035(7%) 뿐이었다
      // = 폭 8배에 여백 0.57dp. 지금은 여백이 **자기 폭 곡선(0.5)** 과
      // **자기 px clamp** 를 갖는다. 무심코 되돌리지 말 것.
      final small = BbSpace.forWidth(320);
      final big = BbSpace.forWidth(960);
      expect(big.xl / small.xl, closeTo(1.6, 0.01),
          reason: '자산 탭 승인 스팬(padH 10→16 = 1.6배)을 지나가야 한다');
      expect(big.md / small.md, closeTo(10 / 6, 0.02));

      // textScaler 는 **clamp 밖**에서 곱해진다 → 상한에 잘리지 않는다.
      final plain = BbSpace.forWidth(390);
      final scaled =
          BbSpace.forWidth(390, scaler: const TextScaler.linear(1.6));
      expect(scaled.md / plain.md, closeTo(1.265, 0.02)); // sqrt(1.6)
      // 상한에 붙은 폭(웹)에서도 배율 결합이 살아 있어야 한다 — clamp 안에 넣으면 죽는다.
      final webPlain = BbSpace.forWidth(1440);
      final webScaled =
          BbSpace.forWidth(1440, scaler: const TextScaler.linear(1.6));
      expect(webScaled.xl / webPlain.xl, closeTo(1.265, 0.02),
          reason: '배율 결합이 상한에 잘렸다 — clamp 밖에서 곱해야 한다');
    });

    test('★여백 토큰이 자산 탭 승인값을 지나간다', () {
      const map = <BbSpaceToken, String>{
        BbSpaceToken.xl: 'tilePaddingH',
        BbSpaceToken.lg: 'radiusMd',
        BbSpaceToken.md: 'gap',
        BbSpaceToken.sm: 'chipPaddingH',
      };
      map.forEach((token, key) {
        final a = anchors[key]!;
        // 320px 은 전 토큰이 하한 clamp 구간 → 정확 일치.
        // (부동소수 마지막 비트만 허용 — 11.999999999999998 은 12 이다)
        expect(BbSpace.forWidth(320).value(token), closeTo(a.compact, 1e-9),
            reason: '$token 의 모바일 하한이 승인값 ${a.compact} 과 달라졌다');
        // 960 이상은 상한 → 정확 일치.
        for (final w in [960.0, 1440.0, 2560.0]) {
          expect(BbSpace.forWidth(w).value(token), closeTo(a.wide, 1e-9),
              reason: 'w=$w 에서 $token 이 승인값 ${a.wide} 과 달라졌다');
        }
        // 360/390 은 하한 근방 — 승인값 이상, 0.5dp 이내.
        for (final w in [360.0, 390.0]) {
          final v = BbSpace.forWidth(w).value(token);
          expect(v, greaterThanOrEqualTo(a.compact - 0.001));
          expect(v, lessThanOrEqualTo(a.compact + 0.5));
        }
        // 중간 대역은 두 승인값 사이(계단↔곡선 허용 오차).
        for (final w in [400.0, 500.0, 600.0, 768.0, 839.0]) {
          final v = BbSpace.forWidth(w).value(token);
          expect(v, greaterThanOrEqualTo(a.compact - 0.001));
          expect(v, lessThanOrEqualTo(a.wide + 0.001));
        }
      });
    });

    test('★박스·크롬 토큰이 승인값을 지나간다 + 터치 하한을 지킨다', () {
      const map = <BbBoxRole, String>{
        BbBoxRole.avatar: 'avatar',
        BbBoxRole.avatarIcon: 'avatarIcon',
        BbBoxRole.actionIcon: 'actionIcon',
      };
      map.forEach((role, key) {
        final a = anchors[key]!;
        expect(BbBox.forWidth(320).size(role), closeTo(a.compact, 1e-9));
        expect(BbBox.forWidth(960).size(role), closeTo(a.wide, 1e-9));
      });
      // L4-2: 액션 슬롯은 어떤 폭에서도 44dp 아래로 내려가지 않는다.
      for (final w in widths) {
        expect(BbBox.forWidth(w).actionSlot, greaterThanOrEqualTo(44.0),
            reason: 'w=$w 에서 액션 탭 타깃이 44dp 아래다');
      }
      // L4-3: M3 Switch 트랙은 고정 치수다 — 곡선을 타지 않는다.
      expect(BbBox.forWidth(320).toggleSlot, 52);
      expect(BbBox.forWidth(2560).toggleSlot, 52);
    });

    test('★계단이 아니다 — 옛 브레이크포인트에서 불연속이 없다', () {
      // `BbDensity` 는 400/840 에서 값이 점프했다. 곡선은 그 지점에서 매끄럽다.
      for (final edge in [400.0, 600.0, 840.0, 960.0]) {
        for (final token in BbSpaceToken.values) {
          final lo = BbSpace.forWidth(edge - 0.1).value(token);
          final hi = BbSpace.forWidth(edge + 0.1).value(token);
          expect((hi - lo).abs(), lessThan(0.05),
              reason: 'w=$edge 에서 $token 이 ${(hi - lo).abs()} 만큼 점프했다 = 계단');
        }
        for (final role in BbBoxRole.values) {
          final lo = BbBox.forWidth(edge - 0.1).size(role);
          final hi = BbBox.forWidth(edge + 0.1).size(role);
          expect((hi - lo).abs(), lessThan(0.05),
              reason: 'w=$edge 에서 $role 이 점프했다 = 계단');
        }
      }
    });

    test('★단조 증가 — 폭이 커질 때 어떤 축도 줄지 않는다', () {
      for (var w = 300.0; w < 2560; w += 20) {
        for (final token in BbSpaceToken.values) {
          expect(BbSpace.forWidth(w + 20).value(token),
              greaterThanOrEqualTo(BbSpace.forWidth(w).value(token) - 1e-9),
              reason: 'w=$w → ${w + 20} 에서 $token 이 줄었다');
        }
        for (final role in BbBoxRole.values) {
          expect(BbBox.forWidth(w + 20).size(role),
              greaterThanOrEqualTo(BbBox.forWidth(w).size(role) - 1e-9));
        }
      }
    });

    test('★테마 여백이 폭에 반응한다 — 하드코딩 16/12 회귀 방지', () {
      final mobile = AppTheme.responsive(AppTheme.light, 360);
      final web = AppTheme.responsive(AppTheme.light, 1440);
      EdgeInsets pad(ThemeData t) =>
          t.inputDecorationTheme.contentPadding! as EdgeInsets;
      expect(pad(mobile).left, lessThan(pad(web).left),
          reason: '입력 필드 여백이 폭에 반응하지 않는다 (테마 하드코딩 회귀)');
      expect(mobile.listTileTheme.contentPadding,
          isNot(web.listTileTheme.contentPadding));
      expect(mobile.cardTheme.margin, isNot(web.cardTheme.margin));
      // 밀도도 계단이 아니라 연속이다.
      final mid = AppTheme.responsive(AppTheme.light, 600).visualDensity;
      expect(mid.horizontal, greaterThan(mobile.visualDensity.horizontal));
      expect(mid.horizontal, lessThan(web.visualDensity.horizontal));
    });

    test('hairline 은 결합하지 않는다 — 0.5/1.0 은 토큰 사다리에 없다', () {
      for (final spec in kBbSpaceSpec.values) {
        expect(spec.min, greaterThan(1.0));
        expect(spec.max, greaterThan(1.0));
      }
    });

    test('컨테이너 폭 판정이 화면 폭 판정과 다르다', () {
      // ★calynda 가 실측한 결함: 화면은 넓은데 자기 폭은 좁은 자리(우측 패널·그리드
      // 셀)에서 `MediaQuery` 로 판정하면 "데스크톱"으로 그린다.
      // 좁은 컨테이너는 반드시 더 작아야 한다.
      expect(BbType.forWidth(300).body, lessThan(BbType.forWidth(1440).body));
      expect(BbType.forWidth(300).title, lessThan(BbType.forWidth(1440).title));

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
                      bbTab(context,
                          icon: Icons.bar_chart_outlined, label: '통계'),
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
                          child:
                              Center(child: Text('데이터', key: Key('content'))),
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
          find
              .ancestor(
                of: find.byKey(const Key('content')),
                matching: find.byType(Expanded),
              )
              .first,
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
        widthsSeen[ts] =
            tester.getSize(find.byKey(const Key('content')).first).width;
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
