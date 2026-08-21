import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';

/// 세로 리듬 가드 (2026-08-21, 2차).
///
/// 왜 이 파일이 있나: 1차 회차는 **지표를 틀려서** 실패했다. 사용자가 말한 것은
/// "항목 1과 2 **사이의 빈 공간**"인데 나는 **행 높이**로 판단했다. 두 지표의 지배 변수가
/// 다르다 `[측정 2026-08-21]`:
///
/// - 행 높이 48.0dp @390 = **아바타 32(67%)** + 패딩 16(33%)
/// - 텍스트 사이 28.0dp @390 = **패딩 16(57%)** + 아바타 오버행 12(43%)
///
/// 그래서 1차의 `lg`→`md` 는 사이를 28.0 → 24.7dp(−12%) 만 줄여 체감이 없었다(PR #305 되돌림).
/// 승인값은 `xs` = **사이 18.0dp @390 / 25.0 @960**.
///
/// ★승인값은 **이 테스트가 소유한다** — `kBbSpaceSpec` 에서 읽어 오면 순환 검증이 되고
/// "곡선을 바꿨더니 기준점도 같이 움직였다"를 잡을 수 없다.
const approvedTextGap = (at390: 18.0, at960: 25.0);

void main() {
  Future<void> pumpPair(WidgetTester t, double w) async {
    await t.binding.setSurfaceSize(Size(w, 1200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.responsive(AppTheme.light, w),
      home: Scaffold(
        body: BbScaleScope(
          width: w,
          child: const Column(children: [
            EntityTileRow(
              title: '신한 주거래',
              leadingIcon: Icons.account_balance,
              trailingMetric: EntityMetric(value: '+1,234,567'),
            ),
            EntityTileRow(
              title: '카카오뱅크',
              leadingIcon: Icons.account_balance,
              trailingMetric: EntityMetric(value: '+99,000'),
            ),
          ]),
        ),
      ),
    ));
  }

  group('V1. 항목 1과 2 사이 빈 공간 — 사용자 승인값', () {
    testWidgets('390 / 960 에서 승인값을 지나간다', (tester) async {
      for (final entry in {
        390.0: approvedTextGap.at390,
        960.0: approvedTextGap.at960
      }.entries) {
        await pumpPair(tester, entry.key);
        final gap = tester.getRect(find.text('카카오뱅크')).top -
            tester.getRect(find.text('신한 주거래')).bottom;
        expect(gap, closeTo(entry.value, 0.51),
            reason: 'w=${entry.key} 항목 사이 빈 공간이 승인값 ${entry.value}dp 에서 벗어났다 '
                '(측정 $gap). 이 값이 사용자가 지적한 그 지표다.');
      }
    });

    testWidgets('세로 padding 은 xs 하나뿐 — 가로는 건드리지 않는다', (tester) async {
      for (final w in [320.0, 390.0, 960.0]) {
        await pumpPair(tester, w);
        final padding = tester
            .widgetList<Padding>(find.descendant(
              of: find.byType(InkWell),
              matching: find.byType(Padding),
            ))
            .first
            .padding
            .resolve(TextDirection.ltr);
        final space = BbSpace.forWidth(w);
        expect(padding.top, closeTo(space.xs, 1e-9),
            reason: 'w=$w 세로 padding 이 xs 에서 벗어났다');
        expect(padding.bottom, closeTo(space.xs, 1e-9));
        expect(padding.left, closeTo(space.xl, 1e-9),
            reason: 'w=$w 가로가 바뀌었다 — 이번 회차는 세로 한 축만 만진다');
      }
    });

    test('소스에도 한 곳뿐이다', () {
      final src =
          File('lib/core/widgets/entity_tile_row.dart').readAsStringSync();
      expect(src.contains('vertical: space.xs'), isTrue);
      expect(src.contains('vertical: space.lg'), isFalse,
          reason: '1차에서 되돌린 값으로 회귀했다');
      expect(src.contains('vertical: space.md'), isFalse,
          reason: '1차에서 체감 없다고 판정된 값(−12%)으로 회귀했다');
    });
  });

  group('V2. 스크롤 TabBar 는 tabAlignment 를 명시한다', () {
    test('isScrollable: true 인 모든 곳에 tabAlignment 가 있다', () {
      final offenders = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = file.readAsStringSync();
        if (!src.contains('isScrollable: true')) continue;
        // TabBar 한 개당 tabAlignment 한 개 — 개수로 대조한다.
        final scrollables = 'isScrollable: true'.allMatches(src).length;
        final aligned = 'tabAlignment:'.allMatches(src).length;
        if (aligned < scrollables) {
          offenders
              .add('${file.path} (scrollable=$scrollables aligned=$aligned)');
        }
      }
      expect(offenders, isEmpty,
          reason: 'M3 스크롤 탭의 기본값은 startOffset = 왼쪽 52dp 죽은 여백이다 '
              '`[측정 2026-08-21]`. 명시하지 않으면 탭이 오른쪽으로 잘린다: $offenders');
    });
  });
}
