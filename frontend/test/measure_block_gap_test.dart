// 계측 전용(9차 대조군) — **블록 사이** 보이는 간격 실측.
//
// 왜 리터럴을 세는 것으로 부족한가 `[측정 2026-08-26]`: `BbCardTile` 의 세로 margin 이
// `space.xs`(4.0 상수)다. 그래서 **같은 `SizedBox(height: 16)` 이 이웃이 카드인지에 따라
// 16.0 · 20.0 · 24.0 세 값으로 보인다**. 소스 리터럴 분포(16:160 · 24:43 · 32:25)는
// 사용자가 보는 간격의 분포가 아니다.
//
// 지표 정의: 블록 i 의 **가장 아래 잉크** → 블록 i+1 의 **가장 위 잉크**(항목 사이 지표와 동일).
// 6차 이후 모든 회차가 이 정의를 쓴다 — 잉크가 아니라 상자를 재면 margin/padding 이 섞여
// 사용자가 보는 빈 공간과 어긋난다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/bb_card_tile.dart';

const widths = <double>[320, 390, 768, 960];

Rect _rect(Element e) {
  final ro = e.renderObject! as RenderBox;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

/// 한 블록이 그리는 잉크 상자(텍스트·아이콘·아바타·진행바 전체).
Rect? inkOf(Finder block) {
  final rects = <Rect>[];
  for (final f in [
    find.byType(Text),
    find.byType(Icon),
    find.byType(CircleAvatar),
    find.byType(LinearProgressIndicator),
  ]) {
    rects.addAll(find.descendant(of: block, matching: f).evaluate().map(_rect));
  }
  if (rects.isEmpty) return null;
  return rects.reduce((a, b) => a.expandToInclude(b));
}

Future<void> _pump(WidgetTester t, double w, List<Widget> children) async {
  t.view.physicalSize = Size(w, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  ));
  await t.pumpAndSettle();
}

Widget _card(String label) => BbCardTile(
      key: Key(label),
      child: Text(label),
    );

Widget _plain(String label) => Container(
      key: Key(label),
      alignment: Alignment.centerLeft,
      child: Text(label),
    );

double _gap(String a, String b) {
  final ra = inkOf(find.byKey(Key(a)))!;
  final rb = inkOf(find.byKey(Key(b)))!;
  return rb.top - ra.bottom;
}

void main() {
  // ───────────────────────────────────────────────────────────────────────
  // P1~P3. 같은 리터럴이 이웃 종류에 따라 몇으로 보이나
  // ───────────────────────────────────────────────────────────────────────
  for (final lit in <double>[16, 24, 32]) {
    for (final w in widths) {
      testWidgets('P|리터럴 $lit|w=$w|카드↔카드', (t) async {
        await _pump(t, w, [_card('a'), SizedBox(height: lit), _card('b')]);
        // ignore: avoid_print
        print('BLOCK|lit=$lit|w=$w|카드↔카드|${_gap('a', 'b').toStringAsFixed(2)}');
      });
      testWidgets('P|리터럴 $lit|w=$w|비카드↔비카드', (t) async {
        await _pump(t, w, [_plain('a'), SizedBox(height: lit), _plain('b')]);
        // ignore: avoid_print
        print('BLOCK|lit=$lit|w=$w|비카드↔비카드|${_gap('a', 'b').toStringAsFixed(2)}');
      });
      testWidgets('P|리터럴 $lit|w=$w|카드↔비카드', (t) async {
        await _pump(t, w, [_card('a'), SizedBox(height: lit), _plain('b')]);
        // ignore: avoid_print
        print('BLOCK|lit=$lit|w=$w|카드↔비카드|${_gap('a', 'b').toStringAsFixed(2)}');
      });
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // P4. 서열 기준선 — 항목 사이 승인값 vs 신설 후보 vs 필드 후보
  // ───────────────────────────────────────────────────────────────────────
  for (final w in widths) {
    testWidgets('P4|w=$w|토큰 사다리 + 신설 후보 block(24,32)', (t) async {
      await _pump(t, w, [_plain('a')]);
      final ctx = t.element(find.byKey(const Key('a')));
      final space = BbSpace.of(ctx);
      final box = BbBox.of(ctx);
      // 신설 후보 block(min 24, max 32) 을 같은 곡선으로 직접 계산
      final block = bbSaturating((min: 24, max: 32), w, kBbSpaceExponent);
      // 항목 사이(2줄) = 2 × listRowPadV — 7차 승인 계약
      final itemGap = 2 * box.cardRowPadV + 2 * space.xs;
      // ignore: avoid_print
      print('LADDER|w=$w|xs=${space.xs.toStringAsFixed(2)}'
          '|lg=${space.lg.toStringAsFixed(2)}'
          '|xl=${space.xl.toStringAsFixed(2)}'
          '|xxl=${space.xxl.toStringAsFixed(2)}'
          '|block*=${block.toStringAsFixed(2)}'
          '|항목사이=${itemGap.toStringAsFixed(2)}');
    });
  }
}
