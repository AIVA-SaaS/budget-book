// 계측 전용 — **전역 항목 간격 스윕**(2026-08-24).
//
// 사용자 요구: "위아래 항목 간 간격을 20.0 으로 모두 통일 => 전역 UI".
// 그래서 목록 표면마다 인접 항목의 **잉크 사이 빈 공간**을 같은 방법으로 잰다.
//
// 지표 정의(3차 승인값과 동일): 항목 i 의 **가장 아래 잉크** → 항목 i+1 의 **가장 위 잉크**.
// ⚠ 텍스트만 보면 안 된다 — 아바타·아이콘·진행바가 텍스트보다 위/아래로 삐져나오면
//   사용자가 보는 빈 공간은 그만큼 좁다(3차에서 "아바타 오버행 12dp" 로 기록된 그 항목).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';

Rect _rect(Element e) {
  final ro = e.renderObject! as RenderBox;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

/// 항목 하나가 그리는 **잉크 상자**: 텍스트 + 아이콘 + 아바타 + 진행바를 모두 감싼다.
Rect? inkOf(Element item) {
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

void report(String surface, double w, Finder itemFinder) {
  final items = itemFinder.evaluate().toList();
  if (items.length < 2) {
    // ignore: avoid_print
    print('SWEEP|$surface|w=$w|항목 ${items.length}개 — 측정 불가');
    return;
  }
  for (var i = 0; i < items.length - 1 && i < 4; i++) {
    final a = inkOf(items[i]);
    final b = inkOf(items[i + 1]);
    if (a == null || b == null) continue;
    // ignore: avoid_print
    print('SWEEP|$surface|w=$w|#$i→#${i + 1}'
        '|잉크사이=${(b.top - a.bottom).toStringAsFixed(1)}'
        '|항목잉크높이=${a.height.toStringAsFixed(1)}');
  }
}

Widget wrap(double w, Widget child) => MaterialApp(
      theme: AppTheme.responsive(AppTheme.light, w),
      home: Scaffold(body: BbScaleScope(width: w, child: child)),
    );

void main() {
  // 기준 표면 — 3차에서 사용자가 "잘 되고 마음에 든다"고 판정한 우리 타일.
  for (final w in [390.0, 960.0]) {
    testWidgets('기준: EntityTileRow(거래·자산 타일) w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(wrap(
          w,
          const Column(children: [
            EntityTileRow(
                title: '신한 주거래',
                leadingIcon: Icons.account_balance,
                trailingMetric: EntityMetric(value: '+1,234,567')),
            EntityTileRow(
                title: '카카오뱅크',
                leadingIcon: Icons.account_balance,
                trailingMetric: EntityMetric(value: '+99,000')),
            EntityTileRow(
                title: '현금',
                leadingIcon: Icons.money,
                trailingMetric: EntityMetric(value: '+30,000')),
          ])));
      await t.pump(const Duration(milliseconds: 300));
      report('기준 EntityTileRow', w, find.byType(EntityTileRow));
    });

    // 레버 응답 곡선 — 잉크 사이는 여백이 아니라 **무엇이 박스를 정하는가**로 바뀐다.
    // ⚠ 내용 주도 행(예산 항목)의 사이는 정확히 `2 × minVerticalPadding` 이므로
    //   여백을 올리면 그쪽이 깨진다. 그래서 아바타 크기의 응답을 먼저 잰다.
    for (final avatar in [40.0, 32.0, 28.0, 24.0, 20.0]) {
      testWidgets('레버: ListTile 2줄 · 아바타 ${avatar}dp w=$w', (t) async {
        await t.binding.setSurfaceSize(Size(w, 1600));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(wrap(
            w,
            Column(children: [
              for (final label in ['점심 식사', '지하철', '영화'])
                ListTile(
                  leading: SizedBox(
                    width: avatar,
                    height: avatar,
                    child: CircleAvatar(
                        child: Icon(Icons.fastfood, size: avatar * 0.5)),
                  ),
                  title: Text(label),
                  subtitle: const Text('식비 · 신한카드'),
                  trailing: const Text('-12,000'),
                ),
            ])));
        await t.pump(const Duration(milliseconds: 300));
        report('ListTile 아바타=$avatar', w, find.byType(ListTile));
      });
    }

    testWidgets('프레임워크 ListTile(2줄) w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(wrap(
          w,
          const Column(children: [
            ListTile(
                leading: CircleAvatar(child: Icon(Icons.fastfood)),
                title: Text('점심 식사'),
                subtitle: Text('식비 · 신한카드'),
                trailing: Text('-12,000')),
            ListTile(
                leading: CircleAvatar(child: Icon(Icons.train)),
                title: Text('지하철'),
                subtitle: Text('교통 · 카카오뱅크'),
                trailing: Text('-1,400')),
            ListTile(
                leading: CircleAvatar(child: Icon(Icons.movie)),
                title: Text('영화'),
                subtitle: Text('문화 · 현금'),
                trailing: Text('-15,000')),
          ])));
      await t.pump(const Duration(milliseconds: 300));
      report('ListTile 2줄', w, find.byType(ListTile));
    });
  }
}
