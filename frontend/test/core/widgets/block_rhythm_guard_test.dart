// 블록 리듬 가드 (2026-08-26, 9차) — **서열 축**을 재는 첫 가드.
//
// 왜 이 파일이 있나: 6·7·8차는 축을 하나씩 추가하면서 **절대값**만 단정했다
// (항목 사이 20.0/25.0). 그래서 한 축을 올리고 다른 축을 그대로 두면 **서열이 역전**돼도
// 전량 초록이었다. 사용자가 본 결함이 정확히 그것이다 `[측정 2026-08-26]`:
// 항목 사이는 20.0 으로 봉인됐는데 최빈 블록 간격이 16 이라 **블록이 항목보다 좁았다**.
//
// 그리고 블록 간격은 아무도 소유하지 않았다 — 보이는 간격이
// `spacer + 위 블록 세로 margin + 아래 블록 세로 margin` 의 합이라, 같은
// `SizedBox(height: 16)` 이 이웃에 따라 **16.00 · 26.00 · 36.00** 으로 갈렸다.
//
// ★R1 이 그 결함의 직접 대조군이다 — 이웃 종류를 바꿔도 같은 토큰이 같은 간격을 만든다.
//   카드가 세로 margin 을 되찾으면 R1 이 즉시 실패한다(변경 전 실측 스프레드 20.00dp).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/bb_card_tile.dart';

const widths = <double>[320, 390, 768, 960];

/// 승인값 — **이 파일이 소유한다**(토큰에서 읽어 오면 순환 검증이 된다).
const approvedItemGap = (at390: 20.0, at960: 25.0);

Future<void> pumpBlocks(WidgetTester t, double w, List<Widget> children) async {
  await t.binding.setSurfaceSize(Size(w, 2000));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.responsive(AppTheme.light, w),
    home: Scaffold(
      body: BbScaleScope(
        width: w,
        child: SingleChildScrollView(
          child: Column(children: children),
        ),
      ),
    ),
  ));
}

/// **칠해진 표면**의 사각형.
///
/// ⚠ 계측 함정(2026-08-26 대조군 1회차에 실제로 밟았다): `Card` 의 `RenderBox` 는
/// **자기 margin 을 포함**한다. 그래서 키를 붙인 위젯의 rect 로 재면 카드가 세로 margin 을
/// 되찾아도 간격이 그대로 나와 **대조군이 통과해 버린다**(축을 눈속임한 것이다).
/// 사용자가 보는 경계는 안쪽 `Material` 이므로 그것을 잡는다.
Rect surfaceRect(WidgetTester t, Key k) {
  final inner = find.descendant(of: find.byKey(k), matching: find.byType(Material));
  return t.getRect(inner.evaluate().isEmpty ? find.byKey(k) : inner.first);
}

double boxGap(WidgetTester t, Key a, Key b) =>
    surfaceRect(t, b).top - surfaceRect(t, a).bottom;

Widget card(String k) => BbCardTile(key: Key(k), child: Text(k));
Widget plain(String k) =>
    Container(key: Key(k), alignment: Alignment.centerLeft, child: Text(k));

void main() {
  group('R1. 같은 토큰은 이웃 종류에 관계없이 같은 간격을 만든다 — 원인 ⓿ 봉인', () {
    // ★대조군 실측(2026-08-26): 카드에 세로 margin(`space.xs`)과 `cardTheme` 세로(`sm`)를
    // 되살려 이 테스트를 돌리면 **같은 토큰인데 24.0 / 28.0 / 32.0** 으로 갈린다
    // (비카드↔비카드 / 카드↔비카드 / 카드↔카드 @320·390·768·960, 스프레드 **8.0dp**).
    // 되돌리면 4/4 통과한다 — 이 축이 원인 ⓿ 에 걸려 있다는 증거다.
    //
    // ⚠ 첫 대조군은 **통과했다**. 키를 붙인 위젯의 rect 로 쟀기 때문이다(`Card` 의
    // RenderBox 는 자기 margin 을 포함한다). 지표를 `surfaceRect` 로 바꿔서야 잡혔다 —
    // **대조군이 통과하면 축이나 지표가 틀린 것이다.**
    for (final w in widths) {
      testWidgets('w=$w — 세 이웃 조합의 간격이 같다', (t) async {
        final gap = BbSpace.forWidth(w).block;
        await pumpBlocks(t, w, [
          plain('p1'),
          SizedBox(height: gap),
          plain('p2'),
          SizedBox(height: gap),
          card('c1'),
          SizedBox(height: gap),
          card('c2'),
        ]);
        final pp = boxGap(t, const Key('p1'), const Key('p2'));
        final pc = boxGap(t, const Key('p2'), const Key('c1'));
        final cc = boxGap(t, const Key('c1'), const Key('c2'));
        final spread = [pp, pc, cc].reduce((a, b) => a > b ? a : b) -
            [pp, pc, cc].reduce((a, b) => a < b ? a : b);
        expect(spread, closeTo(0, 0.01),
            reason: 'w=$w 같은 토큰인데 이웃 종류에 따라 간격이 갈렸다 '
                '(비카드↔비카드 $pp · 카드↔비카드 $pc · 카드↔카드 $cc). '
                '카드가 세로 margin 을 되찾으면 이 값이 0 이 아니게 된다 — '
                '대조군 실측 스프레드는 8.00dp 였다');
      });
    }
  });

  group('R2. 블록 간격은 `block` 토큰값을 그대로 지나간다', () {
    for (final w in widths) {
      testWidgets('w=$w — 카드 사이 블록 간격 == block', (t) async {
        final space = BbSpace.forWidth(w);
        await pumpBlocks(t, w, [
          card('a'),
          SizedBox(height: space.block),
          card('b'),
        ]);
        expect(boxGap(t, const Key('a'), const Key('b')),
            closeTo(space.block, 0.01),
            reason: 'w=$w 보이는 블록 간격이 토큰값과 다르다 — '
                '누군가 자기 밖의 세로 여백을 다시 소유하고 있다');
      });
    }
  });

  group('R3. 서열 단조성 — 블록 > 항목 > 필드', () {
    // ★이번 회차의 계약이다. 절대값 가드만 쌓으면 역전을 못 잡는다(6~8차 4회 반복).
    for (final w in widths) {
      test('w=$w — block > 항목 사이 > 필드(xxl)', () {
        final space = BbSpace.forWidth(w);
        final box = BbBox.forWidth(w);
        final itemGap = box.cardItemGap + 2 * box.cardRowPadV;
        expect(space.block, greaterThan(itemGap),
            reason: 'w=$w 블록 사이(${space.block})가 항목 사이($itemGap)보다 '
                '넓지 않다 — 블록 경계가 사라져 "붙은 채로" 보인다. '
                '사용자가 본 결함이 이것이고 변경 전 값은 16.0 < 20.0 이었다');
        expect(itemGap, greaterThan(space.xxl),
            reason: 'w=$w 항목 사이($itemGap)가 필드 사이(${space.xxl})보다 '
                '넓지 않다 — 목록 항목이 폼 필드보다 촘촘해진다');
      });
    }

    test('최소 마진이 허용오차보다 크다 — 768dp 가 가장 좁다', () {
      // `[추론: 곡선 직접 계산]` 필드 21.47 vs 항목 22.36 = 0.89dp. 허용오차 0.51 보다 크다.
      var worst = double.infinity;
      double worstAt = 0;
      for (final w in widths) {
        final box = BbBox.forWidth(w);
        final itemGap = box.cardItemGap + 2 * box.cardRowPadV;
        final margin = itemGap - BbSpace.forWidth(w).xxl;
        if (margin < worst) {
          worst = margin;
          worstAt = w;
        }
      }
      expect(worst, greaterThan(0.51),
          reason: '서열 마진이 가드 허용오차(0.51) 아래로 내려갔다 '
              '(최소 $worst @${worstAt}dp) — 축이 느슨해져 역전을 못 잡는다');
    });
  });

  group('R4. 무회귀 — 7차·8차 승인값이 살아 있다', () {
    test('항목 사이 승인값 항등식이 유지된다', () {
      for (final e in [(390.0, approvedItemGap.at390), (960.0, approvedItemGap.at960)]) {
        final box = BbBox.forWidth(e.$1);
        expect(box.cardItemGap + 2 * box.cardRowPadV, closeTo(e.$2, 0.51),
            reason: 'w=${e.$1} 카드형 항목 사이가 승인값 ${e.$2} 에서 벗어났다 — '
                '소유권을 옮길 때 값이 바뀌면 안 된다');
      }
    });

    test('cardItemGap 은 폭 상수 8.0 이다 — 두 앵커를 동시에 지나가는 유일한 형태', () {
      for (final w in widths) {
        expect(BbBox.forWidth(w).cardItemGap, closeTo(8.0, 1e-9),
            reason: 'w=$w cardItemGap 이 곡선을 타기 시작하면 '
                '20.0@390 과 25.0@960 을 동시에 지나갈 수 없다');
      }
    });
  });

  group('R5. 소스 봉인 — 도달 가능 화면에 크기 리터럴이 없다', () {
    // 도달 불가 화면(진입점이 죽은 6개)은 제외한다 — 사용자가 볼 수 없다.
    const dead = {
      'dashboard_page.dart',
      'home_page.dart',
      'monthly_trend_card.dart',
      'category_breakdown_card.dart',
      'payment_method_page.dart',
      'category_page.dart',
    };

    /// 주석을 제거한 코드만 본다 — 7차에 폐기한 표현을 주석에 인용했더니 봉인이
    /// **조용히 통과**했다. 봉인은 주석 문구로 만족될 수 있으면 봉인이 아니다.
    Iterable<(String, int, String)> codeLines() sync* {
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (dead.contains(f.uri.pathSegments.last)) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          final t = l.trimLeft();
          if (t.startsWith('//') || t.startsWith('///') || t.startsWith('*')) {
            continue;
          }
          if (l.contains('ui-fixed:')) continue;
          yield (f.path, i + 1, l);
        }
      }
    }

    test('세로 간격 리터럴 0 — `gapV(token)` 이 유일 경로다', () {
      final bad = <String>[];
      for (final (p, n, l) in codeLines()) {
        final m = RegExp(r'SizedBox\(\s*height:\s*([0-9]+(?:\.[0-9]+)?)\s*\)')
            .firstMatch(l);
        if (m == null) continue;
        // L4-4: 0 과 1 은 의미상 없음/최소라 허용한다.
        if (m.group(1) == '0' || m.group(1) == '1') continue;
        bad.add('$p:$n  ${l.trim()}');
      }
      expect(bad, isEmpty,
          reason: '세로 간격이 리터럴로 새고 있다(${bad.length}건). '
              '`context.bbSpace.gapV(BbSpaceToken.…)` 를 쓰거나 '
              '불가피하면 `// ui-fixed: <이유>` 를 달아라:\n${bad.take(10).join('\n')}');
    });

    test('폰트 리터럴 0 — 역할 토큰이 유일 경로다', () {
      final bad = <String>[];
      for (final (p, n, l) in codeLines()) {
        if (RegExp(r'fontSize:\s*[0-9]').hasMatch(l)) bad.add('$p:$n  ${l.trim()}');
      }
      expect(bad, isEmpty,
          reason: '폰트 크기가 리터럴로 새고 있다(${bad.length}건). '
              '`context.bbType.style(role)` / `context.bbType.<role>` 를 써라:\n'
              '${bad.take(10).join('\n')}');
    });

    test('아이콘 크기 리터럴 0 — `BbIconRole` 사다리가 유일 경로다', () {
      final bad = <String>[];
      final lines = codeLines().toList();
      for (var i = 0; i < lines.length; i++) {
        final (p, n, l) = lines[i];
        final m = RegExp(r'\bsize:\s*([0-9]+(?:\.[0-9]+)?)\b').firstMatch(l);
        if (m == null) continue;
        final v = double.parse(m.group(1)!);
        // 44 이상은 아이콘이 아니라 아바타·일러스트다(별도 축 · `BbBox` 소관).
        if (v >= 44) continue;
        // 아이콘 문맥만 본다 — `size:` 는 아이콘 전용 인자가 아니다.
        final win = lines
            .sublist((i - 3).clamp(0, lines.length), (i + 2).clamp(0, lines.length))
            .where((e) => e.$1 == p)
            .map((e) => e.$3)
            .join('\n');
        if (!RegExp(r'Icon\(|IconButton\(|icon:\s*Icon').hasMatch(win)) continue;
        bad.add('$p:$n  ${l.trim()}');
      }
      expect(bad, isEmpty,
          reason: '아이콘 크기가 리터럴로 새고 있다(${bad.length}건). '
              '`context.bbType.icon(BbIconRole.…)` 를 써라:\n'
              '${bad.take(10).join('\n')}');
    });

    test('세로 margin 을 갖는 카드가 0개다 — 원인 ⓿ 역봉인', () {
      final bad = <String>[];
      for (final (p, n, l) in codeLines()) {
        if (!l.contains('margin:')) continue;
        if (RegExp(r'margin:.*(vertical:|EdgeInsets\.all\(|only\(\s*(top|bottom)|fromLTRB)')
            .hasMatch(l)) {
          bad.add('$p:$n  ${l.trim()}');
        }
      }
      expect(bad, isEmpty,
          reason: '카드/박스가 자기 밖의 세로 여백을 다시 소유했다(${bad.length}건). '
              '보이는 블록 간격이 `spacer + 위 margin + 아래 margin` 의 합으로 돌아간다:\n'
              '${bad.take(10).join('\n')}');
    });
  });
}
