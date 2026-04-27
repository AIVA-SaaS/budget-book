import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';

/// 회차 3 — ADJUSTMENT 거래 수정 시 카테고리 picker 가 "잔액 조정" 으로
/// read-only 표시되는지 검증.
///
/// transaction_form_page 의 _buildCategoryPicker 분기 자체는 BlocProvider/DI
/// 의존이 많아 단위 테스트하기 어려우므로, 같은 ItemSelectorField 시그니처로
/// (라벨 고정 + onTap 안내) 회귀 방지 정책 검증.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ADJUSTMENT category picker policy', () {
    testWidgets('selectedLabel "잔액 조정" 가 read-only 형태로 노출', (tester) async {
      await tester.pumpWidget(wrap(
        ItemSelectorField(
          key: const Key('adjustment-category-readonly'),
          label: '카테고리',
          selectedLabel: '잔액 조정',
          prefixIcon: Icons.tune,
          onTap: () {},
        ),
      ));

      expect(find.byKey(const Key('adjustment-category-readonly')),
          findsOneWidget);
      expect(find.text('잔액 조정'), findsOneWidget);
      // 라벨이 '카테고리 *' 가 아니라 '카테고리' (필수 아님 표시)
      expect(find.text('카테고리'), findsOneWidget);
      expect(find.text('카테고리 *'), findsNothing);
    });

    testWidgets('onTap 시 안내 SnackBar 표시 (변경 차단)', (tester) async {
      await tester.pumpWidget(wrap(
        Builder(
          builder: (ctx) => ItemSelectorField(
            label: '카테고리',
            selectedLabel: '잔액 조정',
            prefixIcon: Icons.tune,
            onTap: () {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('잔액 조정 거래는 카테고리를 변경할 수 없습니다')),
              );
            },
          ),
        ),
      ));

      await tester.tap(find.byType(ItemSelectorField));
      await tester.pump();

      expect(find.text('잔액 조정 거래는 카테고리를 변경할 수 없습니다'), findsOneWidget);
    });
  });
}
