import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';

/// 슬롯이 리듬을 깨지 못하게 하는 가드 (2026-08-24, 세로 리듬 5차).
///
/// ## 근본 원인 (이 파일이 존재하는 이유) `[측정 2026-08-24]`
///
/// ```
/// 항목 사이 = 행 박스 높이 − 행 잉크 높이
/// 행 박스   = max(아바타, 액션 슬롯, 텍스트 블록) + 2 × 세로 padding
/// ```
///
/// 액션 슬롯이 **정사각 44dp** 였을 때:
/// - 액션 없는 행: 박스 40 − 잉크 20 = 사이 **20** ✅
/// - 액션 있는 행: 박스 52 − 잉크 20 = 사이 **32** ❌
///
/// 즉 **같은 위젯인데 액션 유무로 리듬이 갈렸다**. 여백 토큰으로는 못 고친다 — 여백을
/// 줄여도 슬롯이 박스를 다시 밀어올린다. 그래서 슬롯의 **레이아웃 높이**를 낮추고
/// 히트 영역 44 는 `OverflowBox` 로 유지한다.
///
/// ⚠ 히트 영역은 **위젯 박스로 판정하지 않는다** — 탭이 실제로 라우팅되는지 본다
/// (calynda 2026-08-21: "칩 박스의 16.6%가 뒤로 샜다").
const approvedGap = (at390: 20.0, at960: 25.0);

/// 액션(44dp 터치 슬롯)을 든 행의 계약값 `[측정 2026-08-24]`.
///
/// **사이 20 과 히트 44 는 @390 에서 동시에 성립하지 않는다.** 항등식이 그렇다:
/// 사이 = 박스 − 잉크 이고, 박스 ≥ 슬롯 44, 잉크 20 이므로 사이 ≥ 24.
/// 44 는 터치 하한(도메인 12 L4)이라 줄일 수 없다 — 레이아웃 높이만 낮추고
/// `OverflowBox` 로 히트 영역을 살리려 한 시도는 **탭 라우팅 계측이 반증**했다.
/// 그래서 액션 행은 여백 0 으로 박스를 슬롯에 붙여 **24.0dp**(두 폭 공통)를 쓴다:
/// @390 박스 44 − 잉크 20 = 24 · @960 박스 48 − 잉크 24 = 24 `[측정]`.
/// 승인값 대비 @390 +4.0 · @960 −1.0 — 이 4dp 가 터치 하한을 지키는 값이다.
const actionRowGap = (at390: 24.0, at960: 24.0);

void main() {
  Rect rectOf(Element e) {
    final ro = e.renderObject! as RenderBox;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  /// 행이 그리는 잉크 상자(텍스트+아이콘+아바타).
  Rect inkOf(WidgetTester t, Element item) {
    final rects = <Rect>[];
    for (final f in [
      find.byType(Text),
      find.byType(Icon),
      find.byType(CircleAvatar),
    ]) {
      rects.addAll(find
          .descendant(of: find.byWidget(item.widget), matching: f)
          .evaluate()
          .map(rectOf));
    }
    return rects.reduce((a, b) => a.expandToInclude(b));
  }

  Future<void> pumpRowsWithAction(WidgetTester t, double w,
      {VoidCallback? onAction}) async {
    await t.binding.setSurfaceSize(Size(w, 1200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.responsive(AppTheme.light, w),
      home: Scaffold(
        body: BbScaleScope(
          width: w,
          child: Column(children: [
            EntityTileRow(
              title: '신한 주거래',
              leadingIcon: Icons.account_balance,
              trailingMetric: const EntityMetric(value: '+1,234,567'),
              viewAction: EntityViewAction(
                icon: Icons.tune,
                tooltip: '잔액 수정',
                onPressed: onAction ?? () {},
              ),
            ),
            EntityTileRow(
              title: '카카오뱅크',
              leadingIcon: Icons.account_balance,
              trailingMetric: const EntityMetric(value: '+99,000'),
              viewAction: EntityViewAction(
                icon: Icons.tune,
                tooltip: '잔액 수정',
                onPressed: onAction ?? () {},
              ),
            ),
          ]),
        ),
      ),
    ));
  }

  group('S1. 액션이 든 행도 같은 사이를 갖는다', () {
    void gapCase(double w, double approved) {
      testWidgets('w=$w — 액션 있는 행 사이 = $approved', (t) async {
        await pumpRowsWithAction(t, w);
        final rows = find.byType(EntityTileRow).evaluate().toList();
        final gap = inkOf(t, rows[1]).top - inkOf(t, rows[0]).bottom;
        expect(gap, closeTo(approved, 0.51),
            reason: 'w=$w 액션 있는 행의 사이가 승인값에서 벗어났다 (측정 $gap). '
                '액션 슬롯이 정사각 44 로 되돌아가면 이 값이 32 로 벌어진다');
      });
    }

    gapCase(390, actionRowGap.at390);
    gapCase(960, actionRowGap.at960);
  });

  group('S2. 히트 영역은 44dp 를 유지한다 — 탭 라우팅으로 판정', () {
    void hitCase(double w) {
      testWidgets('w=$w — 슬롯 중심 ±(44/2 − 2)dp 탭이 액션으로 라우팅된다', (t) async {
        var fired = 0;
        await pumpRowsWithAction(t, w, onAction: () => fired++);
        final box = BbBox.forWidth(w);
        final center = t.getCenter(find.byIcon(Icons.tune).first);
        final reach = box.actionSlot / 2 - 2;

        await t.tapAt(center);
        await t.pump();
        expect(fired, 1, reason: '중심 탭이 라우팅되지 않았다');

        await t.tapAt(center.translate(0, -reach));
        await t.pump();
        expect(fired, 2,
            reason: 'w=$w 위쪽 ${reach}dp 지점 탭이 새어나갔다 — 레이아웃 높이를 '
                '낮추면서 OverflowBox 로 히트 영역을 유지해야 한다');

        await t.tapAt(center.translate(0, reach));
        await t.pump();
        expect(fired, 3, reason: 'w=$w 아래쪽 ${reach}dp 지점 탭이 새어나갔다');
      });
    }

    hitCase(390);
    hitCase(960);
  });

  group('S3. 소스 봉인 — 슬롯의 레이아웃 높이가 정사각으로 회귀하지 않는다', () {
    test('슬롯은 정사각 44 를 유지하고, 세로 흐름 밖에 있다', () {
      // ★주석을 뺀 코드만 본다(6차: 폐기한 표현을 주석에 인용했더니 이 봉인이
      // 조용히 통과했다).
      final src = File('lib/core/widgets/entity_tile_row.dart')
          .readAsStringSync()
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      // 슬롯은 정사각 44 를 유지한다(터치 하한).
      expect(src.contains('height: box.actionSlot'), isTrue,
          reason: '터치 하한 44 가 사라졌다 — 히트 영역이 새어나간다(탭 라우팅으로 확인됨)');
      // ★6차(2026-08-24): 리듬은 여백 0 이 아니라 **슬롯을 세로 흐름 밖에 두는 것**이
      // 만든다. 여백 0 은 슬롯의 슬랙 24 를 행 안쪽에 갇히게 해 위 12.0 / 아래 4.0 의
      // 3배 비대칭을 만들었다 `[측정]`(사용자 신고 ③). 사이 24.0(S1)은 그대로다 —
      // 박스가 슬롯 44 에 묶이는 것은 여백이 아니라 슬롯의 높이가 정하기 때문이다.
      expect(src.contains('hasTallSlot'), isFalse,
          reason: '슬롯 유무로 여백을 갈랐던 5차 회귀가 돌아왔다');
      expect(src.contains('trailingSlot'), isTrue,
          reason: '슬롯이 다시 제목 행(세로 흐름) 안으로 들어갔다 — '
              '슬랙이 행 안쪽에 갇혀 위아래 비대칭이 된다');
    });

    test('budget_row_actions 의 메뉴 버튼도 같은 계약을 쓴다', () {
      final src = File(
              'lib/features/budget/presentation/widgets/budget_row_actions.dart')
          .readAsStringSync();
      expect(src.contains('height: box.actionIcon'), isTrue,
          reason: '메뉴 버튼이 기본 48dp 로 돌아가면 주간 카드 내부 행 사이가 28dp 가 된다');
    });

    test('자산 현황 그룹 박스는 카드와 같은 세로 계약을 쓴다', () {
      final src =
          File('lib/core/widgets/account_balance_card.dart').readAsStringSync();
      expect(src.contains('vertical: context.bbSpace.xs'), isTrue,
          reason: '그룹 박스 margin 세로가 xs 에서 벗어났다(종전 리터럴 8 → 경계 91dp)');
      expect(src.contains('context.bbBox.cardRowPadV'), isTrue,
          reason: '그룹 박스 padding 세로가 cardRowPadV 에서 벗어났다(종전 리터럴 12)');
    });

    test('주간 카드 내부 항목 사이는 승인값 토큰이다', () {
      final src = File(
              'lib/features/weekly_budget/presentation/widgets/week_summary_card.dart')
          .readAsStringSync();
      expect(src.contains('2 * context.bbBox.listRowPadV'), isTrue,
          reason: '카드 내부 항목 사이가 리터럴로 회귀했다(종전 8 → 사이 28dp)');
    });
  });
}
