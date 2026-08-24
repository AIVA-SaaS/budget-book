// 계측 전용 — **행 안/행 사이 위아래 균형** 전수 스윕 (2026-08-24, 사용자 신고 3건).
//
// 신고: ①거래 탭 아이콘 아래 글자가 붙는다(위는 여백 많음) ②분석(예산)·자산 현황 여백 과다
// ③자산 내 결제수단 항목은 아이콘 위아래 여백이 아예 없다(카테고리 탭도 동일)
//
// 그래서 지표를 **세 개** 동시에 본다:
//   (a) 행 사이 = 앞 행 잉크 하단 → 다음 행 잉크 상단
//   (b) 행 안 위/아래 = 행 박스 상단→잉크 상단 / 잉크 하단→행 박스 하단  ← 균형 지표
//   (c) 선행(leading) 안의 위/아래 = 선행 박스 대비 아이콘·글자 위치
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';

Rect r(Element e) {
  final ro = e.renderObject! as RenderBox;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

Rect? ink(Element item) {
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
        .map(r));
  }
  if (rects.isEmpty) return null;
  return rects.reduce((a, b) => a.expandToInclude(b));
}

void balance(String surface, double w, Finder itemFinder) {
  final items = itemFinder.evaluate().toList();
  for (var i = 0; i < items.length && i < 3; i++) {
    final box = r(items[i]);
    final ii = ink(items[i]);
    if (ii == null) continue;
    // ignore: avoid_print
    print('BAL|$surface|w=$w|#$i'
        '|박스=${box.height.toStringAsFixed(1)}'
        '|위=${(ii.top - box.top).toStringAsFixed(1)}'
        '|아래=${(box.bottom - ii.bottom).toStringAsFixed(1)}');
    if (i + 1 < items.length) {
      final next = ink(items[i + 1]);
      if (next != null) {
        // ignore: avoid_print
        print('BAL|$surface|w=$w|#$i→#${i + 1}'
            '|사이=${(next.top - ii.bottom).toStringAsFixed(1)}');
      }
    }
  }
}

Widget wrap(double w, Widget child) => MaterialApp(
      theme: AppTheme.responsive(AppTheme.light, w),
      home: Scaffold(body: BbScaleScope(width: w, child: child)),
    );

void main() {
  for (final w in [390.0, 960.0]) {
    // ③ 자산 탭 결제수단 행 = 칩(metrics) + 액션 슬롯. 여백 0 계약의 실제 결과를 본다.
    testWidgets('자산 탭형: 칩+액션 행 w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(wrap(
          w,
          Column(children: [
            for (final n in ['신한카드', '삼성카드', '현대카드'])
              EntityTileRow(
                title: n,
                leadingIcon: Icons.credit_card,
                metrics: const [
                  EntityMetric(label: '전월', value: '120,000원'),
                  EntityMetric(label: '미결제', value: '80,000원'),
                  EntityMetric(label: '이번달', value: '45,000원'),
                ],
                viewAction: EntityViewAction(
                    icon: Icons.tune, tooltip: '잔액 수정', onPressed: () {}),
              ),
          ])));
      await t.pump(const Duration(milliseconds: 300));
      balance('자산탭 칩+액션행', w, find.byType(EntityTileRow));
    });

    // 같은 위젯인데 액션이 없는 행 — 여백 계약이 갈리는 지점
    testWidgets('자산 탭형: 칩만(액션 없음) w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(wrap(
          w,
          Column(children: [
            for (final n in ['신한카드', '삼성카드', '현대카드'])
              EntityTileRow(
                title: n,
                leadingIcon: Icons.credit_card,
                metrics: const [
                  EntityMetric(label: '전월', value: '120,000원'),
                  EntityMetric(label: '미결제', value: '80,000원'),
                ],
              ),
          ])));
      await t.pump(const Duration(milliseconds: 300));
      balance('자산탭 칩만', w, find.byType(EntityTileRow));
    });

    // ① 거래 탭: 선행이 Column(아바타 + 결제수단 글자) 인 ListTile
    testWidgets('거래탭형: 선행 Column(아바타+글자) w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(wrap(w, Builder(builder: (context) {
        Widget lead(String pm) => SizedBox(
              width: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.fastfood, size: context.bbType.iconSm)),
                  Padding(
                    padding: context.bbSpace.only(top: BbSpaceToken.xs),
                    child: Text(pm,
                        maxLines: 1,
                        style: TextStyle(fontSize: context.bbType.caption)),
                  ),
                ],
              ),
            );
        return Column(children: [
          for (final pm in ['롯데', '신한', '현금'])
            ListTile(
              leading: lead(pm),
              title: const Text('점심 식사'),
              subtitle: const Text('식비'),
              trailing: const Text('-12,000'),
            ),
        ]);
      })));
      await t.pump(const Duration(milliseconds: 300));
      // ★실제 결함의 물증: 선행 Column 이 타일 박스를 넘어 **RenderFlex 오버플로우**가
      // 발생한다(390dp). 예외를 증거로 남기고 계측은 계속한다 — 회귀 A/B 를 고치면
      // 이 값이 null 이 되어야 하고, 그때 가드가 `isNull` 로 단정한다.
      final overflow = t.takeException();
      // ignore: avoid_print
      print('OVERFLOW|거래탭 선행Column|w=$w|${overflow ?? "없음"}');
      balance('거래탭 선행Column', w, find.byType(ListTile));

      // 선행 Column 안의 위/아래 균형 — 신고 ①의 지표
      final leads = find.byType(ListTile).evaluate().toList();
      for (var i = 0; i < leads.length && i < 1; i++) {
        final tile = r(leads[i]);
        final avatar = find
            .descendant(
                of: find.byWidget(leads[i].widget),
                matching: find.byType(CircleAvatar))
            .evaluate();
        final pmText = find
            .descendant(
                of: find.byWidget(leads[i].widget), matching: find.text('롯데'))
            .evaluate();
        if (avatar.isEmpty || pmText.isEmpty) continue;
        final a = r(avatar.first);
        final p = r(pmText.first);
        // ignore: avoid_print
        print('LEAD|거래탭 선행|w=$w'
            '|타일박스=${tile.height.toStringAsFixed(1)}'
            '|타일상단→아바타=${(a.top - tile.top).toStringAsFixed(1)}'
            '|아바타→글자=${(p.top - a.bottom).toStringAsFixed(1)}'
            '|글자→타일하단=${(tile.bottom - p.bottom).toStringAsFixed(1)}');
      }
    });
  }
}
