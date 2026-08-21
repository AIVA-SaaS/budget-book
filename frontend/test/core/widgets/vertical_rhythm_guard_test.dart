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
/// **승인값(2026-08-21 2차 조정) = 항목 사이 20.0dp @390 / 25.0 @960.**
/// 사용자가 18.0dp 배포본을 보고 "20 정도로" 지정했고, 같은 값을 **모든 목록**에
/// 적용하라고 했다 — 그래서 이 파일은 우리 타일(`EntityTileRow`)과 프레임워크
/// `ListTile` **양쪽**을 같은 값으로 단정한다.
///
/// ★승인값은 **이 테스트가 소유한다** — `kBbSpaceSpec`/`kBbBoxSpec` 에서 읽어 오면
/// 순환 검증이 되고 "곡선을 바꿨더니 기준점도 같이 움직였다"를 잡을 수 없다.
const approvedTextGap = (at390: 20.0, at960: 25.0);

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

  group('V1-b. 프레임워크 ListTile 도 같은 사이를 갖는다 — 전체 적용', () {
    // 왜 필요한가 `[측정 2026-08-21]`: `ListTile` 은 높이를 SDK 가 소유한다
    // (M3 1줄 56 · 2줄 72 + density) → 손대지 않으면 **사이 34.8dp** 로 우리 타일의
    // 1.7배였다. 테마의 `minVerticalPadding`(2줄 사이 = 2×) + `minTileHeight`
    // (1줄 사이 = − 제목줄) 두 값으로만 결정된다 — 87곳을 개별 수정하지 않는다.
    //
    // ⚠ 계측 함정(2026-08-21): **한 테스트 안에서 폭을 바꾸면 안 된다.** `MaterialApp` 이
    // 테마를 `AnimatedTheme` 로 감싸서 옛 값이 읽힌다(960 에서 390 값이 나왔다).
    // 그래서 폭마다 테스트를 나눈다. 프로덕션 문제는 아니다.
    Future<void> pumpTiles(WidgetTester t, double w) async {
      await t.binding.setSurfaceSize(Size(w, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.responsive(AppTheme.light, w),
        home: Scaffold(
          body: BbScaleScope(
            width: w,
            child: const Column(children: [
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
              ListTile(title: Text('제목만 1'), trailing: Text('-1')),
              ListTile(title: Text('제목만 2'), trailing: Text('-2')),
            ]),
          ),
        ),
      ));
    }

    void gapCase(double w, double approved) {
      testWidgets('w=$w — 2줄(거래·이체) 사이 = $approved', (tester) async {
        await pumpTiles(tester, w);
        final gap = tester.getRect(find.text('지하철')).top -
            tester.getRect(find.text('식비 · 신한카드')).bottom;
        expect(gap, closeTo(approved, 0.51),
            reason: 'w=$w 2줄 ListTile 사이가 승인값에서 벗어났다');
      });

      testWidgets('w=$w — 1줄(설정·선택 시트) 사이 = $approved', (tester) async {
        await pumpTiles(tester, w);
        final gap = tester.getRect(find.text('제목만 2')).top -
            tester.getRect(find.text('제목만 1')).bottom;
        expect(gap, closeTo(approved, 0.51),
            reason: 'w=$w 1줄 ListTile 사이가 승인값에서 벗어났다');
      });
    }

    gapCase(390, approvedTextGap.at390);
    gapCase(960, approvedTextGap.at960);

    test('테마가 두 지렛대를 모두 들고 있다 — 하나만 있으면 SDK 기본 높이가 이긴다', () {
      final theme = AppTheme.responsive(AppTheme.light, 390);
      expect(theme.listTileTheme.minTileHeight, isNotNull,
          reason: 'minTileHeight 가 없으면 SDK 기본 높이(2줄 72+density)가 지배한다');
      expect(theme.listTileTheme.minVerticalPadding,
          closeTo(approvedTextGap.at390 / 2, 0.26),
          reason: '2줄 사이 = 2 × minVerticalPadding 이므로 승인값의 절반이어야 한다');
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
