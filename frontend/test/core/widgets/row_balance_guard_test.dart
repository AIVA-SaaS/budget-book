// 행 안 **위아래 균형** 가드 (2026-08-24, 세로 리듬 6차).
//
// ## 이 파일이 존재하는 이유 `[측정 2026-08-24]`
//
// 3차(PR #308)·5차(PR #313)가 각각 **다른 항**을 건드려 서로를 깼다:
//
// ```
// 행 사이 = 앞 행 아래 여백 + 다음 행 위 여백
// 행 박스 = max(잉크 + 2 × 여백, 터치 슬롯 44)
// ```
//
// - 3차: `minTileHeight: 34` → 박스 45 < 거래 타일 선행 Column 50 → **위 −1.5 / 아래 −4.5**
//   (선행이 박스를 넘어 다음 행과 겹쳤다 — 사용자 신고 ①)
// - 5차: `hasTallSlot ? 0` → 슬롯 44 의 슬랙이 행 **안쪽**에 갇혀 **위 12.0 / 아래 4.0**
//   (사용자 신고 ③)
//
// 그래서 이 가드는 **사이가 아니라 균형**을 본다: 표면 목록을 코드가 열거하고, 각 행에서
// `위 == 아래` 와 `선행이 박스를 넘지 않음`(음수 = 겹침)을 단정한다. 사이의 승인값은
// `row_slot_rhythm_guard_test`(액션 행 24.0) · `vertical_rhythm_guard_test`(18.0/25.0)가 소유한다.
//
// ⚠ **지표 정의가 이 가드의 핵심이다.** 사용자가 "아이콘 위아래 여백"이라고 할 때의
// 아이콘은 **칠해진 원**(아바타)이다. `_Avatar` 는 `CircleAvatar` 가 아니라
// `Container(decoration:)` 이라서 텍스트·아이콘만 재면 원의 위쪽 8.5dp 를 놓친다 —
// 그러면 대칭인 행이 12.5 vs 8.0 으로 **비대칭으로 오독된다** `[측정]`.
// 그래서 여기서는 **배경을 칠하는 상자까지 포함한 페인트 경계**로 잰다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/asset_edit_mode_scope.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_list_tile.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transfer_list_tile.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// 위 − 아래 허용 오차. 0.5 는 dp 반올림 한 칸이다.
const double kBalanceTolerance = 0.51;

Rect _rect(Element e) {
  final ro = e.renderObject! as RenderBox;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

/// 눈에 보이는 표면의 경계 — 텍스트·아이콘 + **배경을 칠하는 상자**(아바타 원·칩 알약).
Rect _paint(Element item) {
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
  for (final e in find
      .descendant(of: find.byWidget(item.widget), matching: find.byType(Container))
      .evaluate()) {
    final c = e.widget as Container;
    if (c.color != null || c.decoration != null) rects.add(_rect(e));
  }
  return rects.reduce((a, b) => a.expandToInclude(b));
}

Widget _wrap(double w, Widget child) => MaterialApp(
      theme: AppTheme.responsive(AppTheme.light, w),
      home: Scaffold(body: BbScaleScope(width: w, child: child)),
    );

/// 한 표면의 행들을 재서 `위 == 아래` 를 단정한다.
void _expectBalanced(String surface, double w, Finder rows) {
  final items = rows.evaluate().toList();
  expect(items, isNotEmpty, reason: '$surface: 행을 못 찾았다 — 픽스처가 깨졌다');
  for (var i = 0; i < items.length; i++) {
    final box = _rect(items[i]);
    final ink = _paint(items[i]);
    final top = ink.top - box.top;
    final bottom = box.bottom - ink.bottom;
    expect(top, greaterThanOrEqualTo(-kBalanceTolerance),
        reason: '$surface w=$w #$i: 잉크가 박스 **위로** 넘쳤다(위 $top) — '
            '선행/슬롯이 박스보다 크다. 3차 회귀와 같은 형태다');
    expect(bottom, greaterThanOrEqualTo(-kBalanceTolerance),
        reason: '$surface w=$w #$i: 잉크가 박스 **아래로** 넘쳤다(아래 $bottom) — '
            '다음 행과 겹친다(사용자 신고 ①)');
    expect(top, closeTo(bottom, kBalanceTolerance),
        reason: '$surface w=$w #$i: 위 $top / 아래 $bottom 로 비대칭이다. '
            '박스 = max(잉크 + 2 × 여백, 슬롯 44) 이고 남는 슬랙은 위아래로 '
            '균등하게 나뉘어야 한다(5차 회귀와 같은 형태다)');
  }
}

/// 주석을 뺀 소스 — 봉인 테스트가 **주석 문구로 통과하는 것**을 막는다.
/// (실제로 이번 회차에 그 오통과를 한 번 봤다: 폐기한 표현을 주석에 인용했더니
///  `row_slot_rhythm_guard` S3 가 통과했다.)
String _code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  const author = TransactionAuthor(id: 'u1', nickname: '홍길동');
  const category = TransactionCategory(
      id: 'c1',
      name: '식비',
      type: 'EXPENSE',
      icon: 'restaurant',
      color: '#FF5733');

  Transaction txn(String id) => Transaction(
        id: id,
        coupleId: 'c1',
        author: author,
        category: category,
        type: 'EXPENSE',
        amount: 12000,
        description: '점심 식사',
        transactionDate: '2026-08-24',
        paymentMethodName: '롯데카드',
        visibility: 'SHARED',
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      );

  Transfer tr(String id) => Transfer(
        id: id,
        coupleId: 'c1',
        author: author,
        sourcePaymentMethod:
            const PaymentMethodRef(id: 'p1', name: '신한 주거래', type: 'BANK'),
        destinationPaymentMethod:
            const PaymentMethodRef(id: 'p2', name: '현금', type: 'CASH'),
        amount: 50000,
        description: '생활비 이체',
        transferDate: '2026-08-24',
        createdAt: DateTime.utc(2026, 8, 1),
      );

  // ★표면 목록을 **코드가 열거**한다 — 주석이 목록을 들면 반드시 어긋난다
  // (calynda 2026-08-19 교훈). 각 항목은 실제 호스트가 쓰는 조합이다.
  final entityRowSurfaces = <String, Widget Function(int)>{
    '자산 탭 결제수단(칩 + 액션 슬롯)': (i) => EntityTileRow(
          title: '신한카드 $i',
          leadingIcon: Icons.credit_card,
          metrics: const [
            EntityMetric(label: '전월', value: '120,000원'),
            EntityMetric(label: '미결제', value: '80,000원'),
          ],
          viewAction: EntityViewAction(
              icon: Icons.tune, tooltip: '잔액 수정', onPressed: () {}),
        ),
    '자산 탭 결제수단(칩만)': (i) => EntityTileRow(
          title: '삼성카드 $i',
          leadingIcon: Icons.credit_card,
          metrics: const [EntityMetric(label: '전월', value: '120,000원')],
        ),
    '자산 현황(1줄 + 잔액 + 액션 슬롯)': (i) => EntityTileRow(
          title: '카카오뱅크 $i',
          leadingIcon: Icons.account_balance,
          trailingMetric: const EntityMetric(value: '+1,234,567'),
          viewAction: EntityViewAction(
              icon: Icons.tune, tooltip: '잔액 수정', onPressed: () {}),
        ),
    '자산 탭 카드(부제목)': (i) => EntityTileRow(
          title: '현대카드 $i',
          leadingIcon: Icons.credit_card,
          subtitle: '마감일: 15일, 결제일: 25일',
        ),
    '카테고리 탭(배지 + 메뉴)': (i) => EntityTileRow(
          title: '식비 $i',
          leadingIcon: Icons.restaurant,
          badges: const [EntityBadge(label: '기본 카테고리')],
          actions: EntityTileActions(
            menu: const [EntityMenuAction(value: 'edit', label: '수정')],
            onMenuSelected: (_) {},
            reorderIndex: 0,
          ),
        ),
    '비활성 행(dimmed)': (i) => EntityTileRow(
          title: '해지한 카드 $i',
          leadingIcon: Icons.credit_card,
          dimmed: true,
        ),
  };

  for (final w in [390.0, 960.0]) {
    group('B1. EntityTileRow 표면 × 균형 (w=$w)', () {
      for (final entry in entityRowSurfaces.entries) {
        testWidgets('${entry.key} — 위 == 아래', (t) async {
          await t.binding.setSurfaceSize(Size(w, 1200));
          addTearDown(() => t.binding.setSurfaceSize(null));
          await t.pumpWidget(_wrap(
              w,
              Column(children: [entry.value(0), entry.value(1)])));
          await t.pump(const Duration(milliseconds: 300));
          expect(t.takeException(), isNull,
              reason: '${entry.key}: 레이아웃 예외(오버플로우)가 났다');
          _expectBalanced(entry.key, w, find.byType(EntityTileRow));
        });
      }

      testWidgets('편집 모드(토글 + 메뉴 + 드래그) — 위 == 아래', (t) async {
        await t.binding.setSurfaceSize(Size(w, 1200));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(_wrap(
            w,
            AssetEditModeScope(
              controller: AssetEditModeController(editing: true),
              child: Column(children: [
                for (var i = 0; i < 2; i++)
                  EntityTileRow(
                    title: '신한카드 $i',
                    leadingIcon: Icons.credit_card,
                    actions: EntityTileActions(
                      isActive: true,
                      onActiveChanged: (_) {},
                      menu: const [
                        EntityMenuAction(value: 'edit', label: '수정')
                      ],
                      onMenuSelected: (_) {},
                      reorderIndex: i,
                    ),
                  ),
              ]),
            )));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
        _expectBalanced('편집 모드', w, find.byType(EntityTileRow));
      });
    });

    group('B2. 거래·이체 타일 — 선행이 박스를 넘지 않는다 (w=$w)', () {
      testWidgets('거래 타일', (t) async {
        await t.binding.setSurfaceSize(Size(w, 1200));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(_wrap(
            w,
            Column(children: [
              TransactionListTile(transaction: txn('t1')),
              TransactionListTile(transaction: txn('t2')),
            ])));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull,
            reason: '거래 타일에서 레이아웃 예외가 났다 — 선행 Column 이 박스를 '
                '넘으면 RenderFlex 오버플로우가 난다(3차 회귀의 물증)');
        _expectBalanced('거래 타일', w, find.byType(ListTile));
      });

      testWidgets('이체 타일', (t) async {
        await t.binding.setSurfaceSize(Size(w, 1200));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(_wrap(
            w,
            Column(children: [
              TransferListTile(transfer: tr('r1')),
              TransferListTile(transfer: tr('r2')),
            ])));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
        _expectBalanced('이체 타일', w, find.byType(ListTile));
      });
    });
  }

  group('B3. 소스 봉인 — 회귀 경로를 막는다', () {
    test('EntityTileRow 의 세로 여백은 조건 없는 대칭이다', () {
      final code = _code('lib/core/widgets/entity_tile_row.dart');
      expect(code.contains('hasTallSlot'), isFalse,
          reason: '슬롯 유무로 여백을 갈랐던 5차 회귀가 돌아왔다 — '
              '박스 하한은 슬롯이 정하고 여백은 항상 대칭이어야 한다');
      expect(code.contains('vertical: space.xs'), isTrue,
          reason: '세로 여백 토큰(xs)이 사라졌다');
      expect(code.contains('height: box.actionSlot'), isTrue,
          reason: '터치 하한 44 가 사라졌다 — 탭이 새어나간다(S2 가 함께 본다)');
    });

    test('거래·이체 타일의 선행에는 아바타만 남는다', () {
      for (final path in [
        'lib/features/transaction/presentation/widgets/transaction_list_tile.dart',
        'lib/features/transaction/presentation/widgets/transfer_list_tile.dart',
      ]) {
        final code = _code(path);
        final at = code.indexOf('leading:');
        final leading = code.substring(at, code.indexOf('title:', at));
        expect(leading.contains('Text('), isFalse,
            reason: '$path: 선행에 캡션이 다시 붙었다 — 선행 높이가 박스를 넘어 '
                '행이 겹친다(사용자 신고 ①). 캡션은 부제목에 둔다');
      }
    });
  });
}
