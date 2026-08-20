import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/entity_group_header.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';

/// 세로 리듬 단일 소스 가드 (2026-08-21).
///
/// 왜 이 파일이 있나 `[측정 2026-08-21]`: 같은 자산 그룹 목록을 그리는 손수 작성 구현이
/// **두 개**였다. 자산 탭은 평면 목록 + 토큰 헤더(그룹 경계 ≈19dp), 분석>예산의 자산현황은
/// 그룹마다 테두리 `Container`(padding 12 / margin 8)를 직접 조립해 **32dp** 였다.
/// 사용자가 "위아래 여백이 다르다"고 본 것이 이 차이다.
///
/// 리터럴 이관만으로는 재발한다(하네스 `ui_pattern` 3회+). 그래서 세로 리듬을 **두 곳**에만
/// 두고 — 타일 내부 = [EntityTileRow], 그룹 경계 = [EntityGroupHeader] — 화면이 자기 값을
/// 갖지 못하게 한다. 이 테스트가 그 계약을 고정한다.
///
/// 승인값은 **이 파일과 `responsive_sweep_test.dart` 가 소유한다**(코드에서 읽으면 순환 검증).
const approvedTilePaddingV = (compact: 6.0, wide: 10.0); // BbSpaceToken.md

void main() {
  Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.responsive(AppTheme.light, width),
      home: Scaffold(
        body: BbScaleScope(width: width, child: child),
      ),
    ));
  }

  group('V1. 타일 세로 padding 은 md 하나뿐이다', () {
    testWidgets('320/390/960 에서 승인값을 지나간다', (tester) async {
      for (final w in [320.0, 390.0, 960.0]) {
        await pumpAt(tester, w, const EntityTileRow(title: '자산 항목'));

        final padding = tester
            .widgetList<Padding>(find.descendant(
              of: find.byType(InkWell),
              matching: find.byType(Padding),
            ))
            .first
            .padding
            .resolve(TextDirection.ltr);

        final space = BbSpace.forWidth(w);
        expect(padding.top, closeTo(space.md, 1e-9),
            reason: 'w=$w 타일 세로 padding 이 md 에서 벗어났다');
        expect(padding.bottom, closeTo(space.md, 1e-9));
        expect(padding.left, closeTo(space.xl, 1e-9),
            reason: 'w=$w 가로는 xl 이어야 한다(세로만 바꾼 회차다)');

        // 승인값: 모바일 6 · 콘텐츠 최대폭 10.
        if (w == 320.0) {
          expect(padding.top, closeTo(approvedTilePaddingV.compact, 1e-9));
        }
        if (w == 960.0) {
          expect(padding.top, closeTo(approvedTilePaddingV.wide, 1e-9));
        }
      }
    });

    testWidgets('아바타 있는 행은 44dp 터치 하한을 지킨다', (tester) async {
      for (final w in [320.0, 390.0]) {
        await pumpAt(
          tester,
          w,
          const EntityTileRow(title: '자산 항목', leadingIcon: Icons.money),
        );
        final height = tester.getSize(find.byType(InkWell)).height;
        expect(height, greaterThanOrEqualTo(44.0),
            reason: 'w=$w 타일 높이 $height — 세로를 더 줄이면 터치 하한을 깬다');
      }
    });
  });

  group('V2. 그룹 헤더는 EntityGroupHeader 하나뿐이다', () {
    const hosts = [
      'lib/core/widgets/account_balance_card.dart',
      'lib/features/settings/presentation/pages/asset_management_page.dart',
    ];

    test('두 호스트가 같은 헤더 위젯을 지난다', () {
      for (final path in hosts) {
        final src = File(path).readAsStringSync();
        expect(src.contains('EntityGroupHeader('), isTrue,
            reason: '$path 가 그룹 헤더를 직접 조립하고 있다 — 리듬이 갈린다');
      }
    });

    test('분석>예산 자산현황은 자기 여백·폰트·테두리를 갖지 않는다', () {
      final src = File(hosts.first).readAsStringSync();
      for (final banned in ['EdgeInsets', 'fontSize:', 'BoxDecoration']) {
        expect(src.contains(banned), isFalse,
            reason: '`$banned` 가 다시 들어왔다 — 그룹 박스를 손수 조립하던 상태로 회귀했다');
      }
    });

    test('EntityGroupHeader API 는 값 타입으로 봉인돼 있다', () {
      final src =
          File('lib/core/widgets/entity_group_header.dart').readAsStringSync();
      for (final banned in [
        'this.padding',
        'this.child',
        'this.style',
        'fontSize:',
        'EdgeInsets',
      ]) {
        expect(src.contains(banned), isFalse,
            reason: '`$banned` 노출 = 호출부가 여백·폰트를 다시 적을 경로가 생겼다');
      }
    });

    test('타일 세로 리듬은 소스에도 한 곳뿐이다', () {
      final src =
          File('lib/core/widgets/entity_tile_row.dart').readAsStringSync();
      expect(src.contains('vertical: space.md'), isTrue);
      expect(src.contains('vertical: space.lg'), isFalse,
          reason: 'lg 로 되돌아갔다 — 2026-08-21 승인값은 md 다');
    });
  });

  group('V3. 헤더 세로 리듬', () {
    testWidgets('헤더 위 여백은 md · 아래는 xs', (tester) async {
      for (final w in [320.0, 960.0]) {
        await pumpAt(
          tester,
          w,
          const EntityGroupHeader(label: '현금', icon: Icons.money),
        );
        final padding = tester
            .widget<Padding>(find
                .ancestor(
                  of: find.text('현금'),
                  matching: find.byType(Padding),
                )
                .first)
            .padding
            .resolve(TextDirection.ltr);
        final space = BbSpace.forWidth(w);
        expect(padding.top, closeTo(space.md, 1e-9));
        expect(padding.bottom, closeTo(space.xs, 1e-9));
        expect(padding.left, closeTo(space.xl, 1e-9));
      }
    });
  });
}
