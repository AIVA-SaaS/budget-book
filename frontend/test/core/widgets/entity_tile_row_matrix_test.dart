import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_colors.dart';
import 'package:budget_book/core/widgets/asset_edit_mode_scope.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';
import 'package:budget_book/core/widgets/one_line_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guard S4 — the tile is measured across 32 combinations, and the matrix
/// deliberately includes the **worst** conditions (320dp · 1.3x text · dark ·
/// edit mode), not just the comfortable ones.
///
/// Worst-case payload: a long real-world name, a 9-digit amount and three
/// chips on the same tile.
void main() {
  const worstCaseName = '카카오뱅크 생활비 공동통장';
  const worstCaseAmount = '123,456,789원';

  const widths = <double>[320, 360, 390, 768];
  const textScales = <double>[1.0, 1.3];
  const brightnesses = <Brightness>[Brightness.light, Brightness.dark];
  const editModes = <bool>[false, true];

  Widget host({
    required double width,
    required double textScale,
    required Brightness brightness,
    required bool editing,
    String name = worstCaseName,
  }) {
    final controller = AssetEditModeController(editing: editing);
    return MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: AssetEditModeScope(
            controller: controller,
            child: SizedBox(
              width: width,
              child: EntityTileRow(
                title: name,
                subtitle: '마감일: 15일, 결제일: 25일',
                leadingIcon: Icons.credit_card,
                badges: const [
                  EntityBadge(label: '기본', tone: EntityTone.neutral),
                ],
                trailingMetric: const EntityMetric(
                  label: '잔액',
                  value: worstCaseAmount,
                  tone: EntityTone.positive,
                ),
                metrics: const [
                  EntityMetric(
                      label: '전월',
                      value: worstCaseAmount,
                      tone: EntityTone.neutral),
                  EntityMetric(
                      label: '미결제',
                      value: worstCaseAmount,
                      tone: EntityTone.expense),
                  EntityMetric(
                      label: '이번달',
                      value: worstCaseAmount,
                      tone: EntityTone.income),
                ],
                actions: EntityTileActions(
                  isActive: true,
                  onActiveChanged: (_) {},
                  menu: const [
                    EntityMenuAction(value: 'edit', label: '수정'),
                    EntityMenuAction(
                        value: 'delete', label: '삭제', destructive: true),
                  ],
                  onMenuSelected: (_) {},
                  reorderIndex: 0,
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  setUp(OneLineLabel.clearCache);

  for (final width in widths) {
    for (final scale in textScales) {
      for (final brightness in brightnesses) {
        for (final editing in editModes) {
          final label = '${width.toInt()}dp · ${scale}x · '
              '${brightness.name} · ${editing ? "edit" : "view"}';

          testWidgets('[$label] lays out without overflow', (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(host(
              width: width,
              textScale: scale,
              brightness: brightness,
              editing: editing,
            ));
            expect(tester.takeException(), isNull,
                reason: '$label overflowed');

            // The name always renders, and never below the legibility floor.
            final paragraph =
                tester.renderObject<RenderParagraph>(find.text(worstCaseName));
            final fontSize = paragraph.text.style!.fontSize!;
            expect(fontSize,
                greaterThanOrEqualTo(OneLineLabel.defaultMinFontSize),
                reason: '$label shrank the name below 12sp');

            if (!editing) {
              // View mode is the readability contract (검증 A1): the whole
              // name is visible, no ellipsis.
              expect(paragraph.didExceedMaxLines, isFalse,
                  reason: '$label truncated the name in view mode');
            } else {
              // Edit mode: the action lane keeps 40dp tap targets.
              for (final finder in [
                find.byType(Switch),
                find.byType(PopupMenuButton<String>),
                find.byType(ReorderableDragStartListener),
              ]) {
                final size = tester.getSize(finder);
                expect(size.height, greaterThanOrEqualTo(40),
                    reason: '$label action height ${size.height}');
                expect(size.width, greaterThanOrEqualTo(40),
                    reason: '$label action width ${size.width}');
              }
            }
          });
        }
      }
    }
  }

  testWidgets('view mode hides the toggle, menu and drag handle',
      (tester) async {
    await tester.pumpWidget(host(
      width: 360,
      textScale: 1.0,
      brightness: Brightness.light,
      editing: false,
    ));
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsNothing);
  });

  testWidgets('edit mode disables row navigation', (tester) async {
    var tapped = 0;
    final controller = AssetEditModeController(editing: true);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: AssetEditModeScope(
          controller: controller,
          child: EntityTileRow(
            title: '현금',
            leadingIcon: Icons.money,
            onTap: () => tapped++,
            actions: EntityTileActions(
              isActive: true,
              onActiveChanged: (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('현금'));
    await tester.pump();
    expect(tapped, 0, reason: '편집 모드에서 행 탭이 거래 탭으로 튀면 안 된다 (검증 B5)');

    controller.exit();
    await tester.pump();
    await tester.tap(find.text('현금'));
    await tester.pump();
    expect(tapped, 1, reason: '보기 모드에서는 기존 동작대로 이동한다');
  });

  testWidgets('viewAction shows in view mode and yields to the edit lane',
      (tester) async {
    var pressed = 0;
    final controller = AssetEditModeController();
    Widget build() => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AssetEditModeScope(
              controller: controller,
              child: SizedBox(
                width: 320,
                child: EntityTileRow(
                  title: '카카오뱅크',
                  leadingIcon: Icons.account_balance,
                  trailingMetric: const EntityMetric(value: '1,200,000원'),
                  viewAction: EntityViewAction(
                    icon: Icons.tune,
                    tooltip: '잔액 수정',
                    onPressed: () => pressed++,
                  ),
                  actions: EntityTileActions(
                    isActive: true,
                    onActiveChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)).width,
        greaterThanOrEqualTo(40));
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump();
    expect(pressed, 1);

    controller.toggle();
    await tester.pump();
    expect(find.byIcon(Icons.tune), findsNothing,
        reason: '편집 모드에서는 액션 레인이 우측을 차지한다');
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('inactive rows are marked in view mode', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: EntityTileRow(
          title: '옛날 카드',
          leadingIcon: Icons.credit_card,
          dimmed: true,
        ),
      ),
    ));
    expect(find.text('비활성'), findsOneWidget);
    expect(find.byType(Opacity), findsWidgets);
  });

  testWidgets('the amount drops below the name instead of truncating it',
      (tester) async {
    // 320dp with 1.3x text cannot fit a long name and a 9-digit amount on
    // one line — the name wins, the amount moves to the chip strip and stays
    // exact (금액 축약 금지).
    await tester.pumpWidget(host(
      width: 320,
      textScale: 1.3,
      brightness: Brightness.light,
      editing: false,
    ));
    expect(tester.takeException(), isNull);
    expect(find.textContaining(worstCaseAmount), findsWidgets);
    final paragraph =
        tester.renderObject<RenderParagraph>(find.text(worstCaseName));
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  group('tone resolution', () {
    test('every chip tone pair clears WCAG body contrast', () {
      for (final bb in [BbColors.light, BbColors.dark]) {
        for (final tone in EntityTone.values) {
          final pair = EntityTileRow.toneChip(bb, tone);
          final ratio =
              BbColors.contrastRatio(pair.foreground, pair.background);
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '${bb.brightness.name} $tone chip = '
                  '${ratio.toStringAsFixed(2)}:1');
        }
      }
    });
  });
}
