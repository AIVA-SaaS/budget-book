import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/filters/filter_chip_group.dart';

void main() {
  const items = [
    FilterChipItem(value: null, label: '전체'),
    FilterChipItem(value: 'PLANNED', label: '계획됨'),
    FilterChipItem(value: 'COMPLETED', label: '완료'),
    FilterChipItem(value: 'SKIPPED', label: '건너뜀'),
    FilterChipItem(value: 'OVERDUE', label: '기한초과'),
  ];

  Widget createWidget({
    String? selectedValue,
    ValueChanged<String?>? onSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FilterChipGroup(
          items: items,
          selectedValue: selectedValue,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    );
  }

  group('FilterChipGroup', () {
    testWidgets('renders all items', (tester) async {
      await tester.pumpWidget(createWidget());
      for (final item in items) {
        expect(find.text(item.label), findsOneWidget);
      }
    });

    testWidgets('highlights selected item', (tester) async {
      await tester.pumpWidget(createWidget(selectedValue: 'PLANNED'));
      final chip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('계획됨'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('tapping unselected chip calls onSelected with value',
        (tester) async {
      String? selectedValue;
      await tester.pumpWidget(createWidget(
        onSelected: (v) => selectedValue = v,
      ));
      await tester.tap(find.text('완료'));
      expect(selectedValue, 'COMPLETED');
    });

    testWidgets('tapping selected chip calls onSelected with null',
        (tester) async {
      String? result = 'NOT_CALLED';
      await tester.pumpWidget(createWidget(
        selectedValue: 'PLANNED',
        onSelected: (v) => result = v,
      ));
      await tester.tap(find.text('계획됨'));
      expect(result, isNull);
    });
  });
}
